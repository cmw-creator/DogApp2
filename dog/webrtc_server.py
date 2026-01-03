"""
WebRTC 视频流服务器
使用 aiortc 和 Flask-SocketIO 实现
"""
import asyncio
import cv2
import logging
import os
import threading
from threading import Thread, Lock
from flask import Flask
from flask_cors import CORS
from flask_socketio import SocketIO, emit
from aiortc import RTCPeerConnection, RTCSessionDescription, VideoStreamTrack
from aiortc.contrib.media import MediaBlackhole
from av import VideoFrame
import numpy as np

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class VideoStreamTrack(VideoStreamTrack):
    """
    自定义视频流轨道，从视频文件读取帧
    """
    def __init__(self, video_path, loop=True):
        super().__init__()
        self.video_path = video_path
        self.loop = loop
        self.cap = None
        self.lock = Lock()
        self._start = None
        
    def _init_capture(self):
        """初始化视频捕获"""
        if self.cap is None or not self.cap.isOpened():
            self.cap = cv2.VideoCapture(self.video_path)
            if not self.cap.isOpened():
                logger.error(f"无法打开视频文件: {self.video_path}")
                return False
            logger.info(f"已打开视频文件: {self.video_path}")
        return True
    
    async def recv(self):
        """接收视频帧"""
        with self.lock:
            if not self._init_capture():
                # 返回黑色帧
                frame = np.zeros((480, 640, 3), dtype=np.uint8)
                new_frame = VideoFrame.from_ndarray(frame, format="bgr24")
                new_frame.pts, new_frame.time_base = await self.next_timestamp()
                return new_frame
            
            ret, frame = self.cap.read()
            if not ret:
                if self.loop:
                    # 循环播放
                    self.cap.set(cv2.CAP_PROP_POS_FRAMES, 0)
                    ret, frame = self.cap.read()
                
                if not ret:
                    # 如果还是读取失败，返回黑色帧
                    frame = np.zeros((480, 640, 3), dtype=np.uint8)
            
            # 转换为 VideoFrame
            new_frame = VideoFrame.from_ndarray(frame, format="bgr24")
            new_frame.pts, new_frame.time_base = await self.next_timestamp()
            
        return new_frame
    
    def stop(self):
        """停止视频流"""
        super().stop()
        with self.lock:
            if self.cap is not None:
                self.cap.release()
                self.cap = None

class WebRTCServer:
    """WebRTC 信令服务器"""
    
    def __init__(self, assets_folder='assets'):
        # 统一使用脚本所在目录作为基准，避免工作目录不同导致找不到文件
        base_dir = os.path.dirname(os.path.abspath(__file__))
        assets_folder = os.path.join(base_dir, assets_folder)

        self.app = Flask(__name__)
        self.app.config['SECRET_KEY'] = 'dog-webrtc-secret-key'
        CORS(self.app)
        # 使用 threading + 独立 asyncio 事件循环的模式
        self.socketio = SocketIO(self.app, cors_allowed_origins="*", async_mode='threading')
        
        self.ASSETS_FOLDER = assets_folder
        self.video_folder = os.path.join(self.ASSETS_FOLDER, 'videos')
        os.makedirs(self.video_folder, exist_ok=True)
        
        # WebRTC 连接管理
        self.pcs = {}  # {session_id: RTCPeerConnection}
        self.video_tracks = {}  # {session_id: VideoStreamTrack}
        self.current_video_path = None
        self.stream_lock = Lock()
        
        # 独立的 asyncio 事件循环在线程中运行，避免在 eventlet 环境下调用 asyncio.run
        self.loop = asyncio.new_event_loop()
        threading.Thread(target=self._start_event_loop, daemon=True).start()
        
        # 设置事件处理器
        self.setup_socketio_events()
        
        logger.info("WebRTC 服务器初始化完成")

    def _start_event_loop(self):
        asyncio.set_event_loop(self.loop)
        self.loop.run_forever()
    
    def setup_socketio_events(self):
        """设置 SocketIO 事件处理器"""
        
        @self.socketio.on('connect')
        def handle_connect():
            logger.info(f"客户端连接: {request.sid}")
            emit('connected', {'session_id': request.sid})
        
        @self.socketio.on('disconnect')
        def handle_disconnect():
            logger.info(f"客户端断开: {request.sid}")
            self.cleanup_peer_connection(request.sid)
        
        @self.socketio.on('offer')
        def handle_offer(data):
            """处理 WebRTC offer"""
            logger.info(f"收到 offer: {request.sid}")
            future = asyncio.run_coroutine_threadsafe(
                self.handle_offer_async(request.sid, data), self.loop
            )
            # 阻塞等待完成，确保 answer 及时发送
            future.result()
        
        @self.socketio.on('ice_candidate')
        def handle_ice_candidate(data):
            """处理 ICE candidate"""
            logger.info(f"收到 ICE candidate: {request.sid}")
            asyncio.run_coroutine_threadsafe(
                self.handle_ice_candidate_async(request.sid, data), self.loop
            )
        
        @self.socketio.on('start_stream')
        def handle_start_stream(data):
            """启动视频流"""
            video_filename = data.get('video_filename')
            if not video_filename:
                emit('error', {'message': '未指定视频文件'})
                return
            
            video_path = os.path.join(self.video_folder, video_filename)
            if not os.path.exists(video_path):
                emit('error', {'message': f'视频文件不存在: {video_filename}'})
                return
            
            with self.stream_lock:
                self.current_video_path = video_path
            
            logger.info(f"设置视频路径: {video_path}")
            emit('stream_started', {'video_filename': video_filename})
        
        @self.socketio.on('stop_stream')
        def handle_stop_stream():
            """停止视频流"""
            logger.info(f"停止视频流: {request.sid}")
            self.cleanup_peer_connection(request.sid)
            emit('stream_stopped', {})
        
        @self.socketio.on('get_videos')
        def handle_get_videos(*args):
            """获取可用视频列表（兼容 SocketIO 传参）"""
            videos = self.get_available_videos()
            emit('videos_list', {'videos': videos})
    
    async def handle_offer_async(self, session_id, data):
        """异步处理 WebRTC offer"""
        try:
            # 清理旧连接
            self.cleanup_peer_connection(session_id)
            
            # 创建新的 RTCPeerConnection
            pc = RTCPeerConnection()
            self.pcs[session_id] = pc
            
            # 添加视频轨道
            if self.current_video_path:
                video_track = VideoStreamTrack(self.current_video_path, loop=True)
                pc.addTrack(video_track)
                self.video_tracks[session_id] = video_track
                logger.info(f"添加视频轨道: {self.current_video_path}")
            else:
                logger.warning("未设置视频路径")
            
            # 设置远程描述
            offer = RTCSessionDescription(sdp=data['sdp'], type=data['type'])
            await pc.setRemoteDescription(offer)
            
            # 创建 answer
            answer = await pc.createAnswer()
            await pc.setLocalDescription(answer)
            
            # 发送 answer
            self.socketio.emit('answer', {
                'sdp': pc.localDescription.sdp,
                'type': pc.localDescription.type
            }, room=session_id)
            
            logger.info(f"已发送 answer: {session_id}")
            
        except Exception as e:
            logger.error(f"处理 offer 失败: {e}", exc_info=True)
            self.socketio.emit('error', {'message': str(e)}, room=session_id)
    
    async def handle_ice_candidate_async(self, session_id, data):
        """异步处理 ICE candidate"""
        try:
            pc = self.pcs.get(session_id)
            if pc is None:
                logger.warning(f"未找到 PeerConnection: {session_id}")
                return
            
            candidate = data.get('candidate')
            if candidate:
                await pc.addIceCandidate(candidate)
                logger.info(f"添加 ICE candidate: {session_id}")
        
        except Exception as e:
            logger.error(f"处理 ICE candidate 失败: {e}", exc_info=True)
    
    def cleanup_peer_connection(self, session_id):
        """清理 PeerConnection"""
        try:
            # 停止视频轨道
            video_track = self.video_tracks.pop(session_id, None)
            if video_track:
                video_track.stop()
            
            # 关闭 PeerConnection 在线程事件循环中执行
            pc = self.pcs.pop(session_id, None)
            if pc:
                future = asyncio.run_coroutine_threadsafe(pc.close(), self.loop)
                future.result()
            
            logger.info(f"清理连接: {session_id}")
        
        except Exception as e:
            logger.error(f"清理连接失败: {e}", exc_info=True)
    
    def get_available_videos(self):
        """获取可用视频列表"""
        try:
            if not os.path.exists(self.video_folder):
                return []
            
            videos = []
            for filename in os.listdir(self.video_folder):
                if filename.endswith(('.mp4', '.avi', '.mov', '.mkv')):
                    videos.append(filename)
            
            return sorted(videos)
        
        except Exception as e:
            logger.error(f"获取视频列表失败: {e}")
            return []
    
    def run(self, host='0.0.0.0', port=5001, debug=False):
        """启动服务器"""
        logger.info(f"启动 WebRTC 服务器: {host}:{port}")
        self.socketio.run(self.app, host=host, port=port, debug=debug)

# 导入 request 用于 SocketIO 事件处理器
from flask import request

if __name__ == '__main__':
    server = WebRTCServer()
    server.run(port=5001, debug=True)
