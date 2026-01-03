import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class WebRTCService {
  final String serverUrl;
  IO.Socket? _socket;
  RTCPeerConnection? _peerConnection;
  MediaStream? _remoteStream;
  RTCVideoRenderer? _remoteRenderer;
  
  bool _isConnected = false;
  bool _isStreaming = false;
  
  // 回调函数
  Function(MediaStream)? onRemoteStream;
  Function(String)? onError;
  Function()? onDisconnected;
  
  WebRTCService({required this.serverUrl});
  
  bool get isConnected => _isConnected;
  bool get isStreaming => _isStreaming;
  MediaStream? get remoteStream => _remoteStream;
  
  /// 初始化 WebRTC
  Future<void> initialize() async {
    try {
      // 创建远程视频渲染器
      _remoteRenderer = RTCVideoRenderer();
      await _remoteRenderer!.initialize();
      
      // 连接 Socket.IO
      await _connectSocket();
      
    } catch (e) {
      _handleError('初始化失败: $e');
    }
  }
  
  /// 连接 Socket.IO 服务器
  Future<void> _connectSocket() async {
    try {
      _socket = IO.io(serverUrl, <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false,
      });
      
      // 设置事件监听器
      _socket!.on('connect', (_) {
        print('Socket.IO 已连接');
        _isConnected = true;
      });
      
      _socket!.on('disconnect', (_) {
        print('Socket.IO 已断开');
        _isConnected = false;
        _isStreaming = false;
        onDisconnected?.call();
      });
      
      _socket!.on('connected', (data) {
        print('收到连接确认: ${data['session_id']}');
      });
      
      _socket!.on('answer', (data) {
        print('收到 answer');
        _handleAnswer(data);
      });
      
      _socket!.on('stream_started', (data) {
        print('视频流已启动: ${data['video_filename']}');
        _isStreaming = true;
      });
      
      _socket!.on('stream_stopped', (_) {
        print('视频流已停止');
        _isStreaming = false;
        _closeConnection();
      });
      
      _socket!.on('error', (data) {
        _handleError('服务器错误: ${data['message']}');
      });
      
      // 连接
      _socket!.connect();
      
      // 等待连接成功
      await Future.delayed(const Duration(seconds: 1));
      
    } catch (e) {
      _handleError('Socket.IO 连接失败: $e');
    }
  }
  
  /// 启动视频流
  Future<void> startStream(String videoFilename) async {
    try {
      if (!_isConnected) {
        throw Exception('未连接到服务器');
      }
      
      // 通知服务器启动视频流
      _socket!.emit('start_stream', {'video_filename': videoFilename});
      
      // 等待服务器确认
      await Future.delayed(const Duration(milliseconds: 500));
      
      // 创建 PeerConnection
      await _createPeerConnection();
      
      // 创建 Offer
      await _createOffer();
      
    } catch (e) {
      _handleError('启动视频流失败: $e');
    }
  }
  
  /// 停止视频流
  Future<void> stopStream() async {
    try {
      _socket?.emit('stop_stream', {});
      await _closeConnection();
      _isStreaming = false;
    } catch (e) {
      _handleError('停止视频流失败: $e');
    }
  }
  
  /// 创建 PeerConnection
  Future<void> _createPeerConnection() async {
    try {
      // ICE 服务器配置
      final configuration = {
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
        ]
      };
      
      // 创建 PeerConnection
      _peerConnection = await createPeerConnection(configuration);
      
      // 监听远程流
      _peerConnection!.onTrack = (RTCTrackEvent event) {
        print('收到远程轨道: ${event.streams.length} 个流');
        if (event.streams.isNotEmpty) {
          _remoteStream = event.streams[0];
          _remoteRenderer!.srcObject = _remoteStream;
          onRemoteStream?.call(_remoteStream!);
        }
      };
      
      // 监听 ICE 状态变化
      _peerConnection!.onIceConnectionState = (state) {
        print('ICE 连接状态: $state');
      };
      
      // 监听连接状态变化
      _peerConnection!.onConnectionState = (state) {
        print('连接状态: $state');
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
          _handleError('连接失败');
        }
      };
      
      // 监听 ICE candidate
      _peerConnection!.onIceCandidate = (candidate) {
        if (candidate != null) {
          print('发送 ICE candidate');
          _socket!.emit('ice_candidate', {
            'candidate': {
              'candidate': candidate.candidate,
              'sdpMid': candidate.sdpMid,
              'sdpMLineIndex': candidate.sdpMLineIndex,
            }
          });
        }
      };
      
    } catch (e) {
      _handleError('创建 PeerConnection 失败: $e');
    }
  }
  
  /// 创建 Offer
  Future<void> _createOffer() async {
    try {
      if (_peerConnection == null) {
        throw Exception('PeerConnection 未初始化');
      }
      
      // 创建 Offer
      RTCSessionDescription offer = await _peerConnection!.createOffer({
        'offerToReceiveVideo': true,
        'offerToReceiveAudio': false,
      });
      
      // 设置本地描述
      await _peerConnection!.setLocalDescription(offer);
      
      // 发送 Offer 到服务器
      print('发送 offer');
      _socket!.emit('offer', {
        'sdp': offer.sdp,
        'type': offer.type,
      });
      
    } catch (e) {
      _handleError('创建 Offer 失败: $e');
    }
  }
  
  /// 处理 Answer
  Future<void> _handleAnswer(Map<String, dynamic> data) async {
    try {
      if (_peerConnection == null) {
        throw Exception('PeerConnection 未初始化');
      }
      
      // 设置远程描述
      RTCSessionDescription answer = RTCSessionDescription(
        data['sdp'],
        data['type'],
      );
      
      await _peerConnection!.setRemoteDescription(answer);
      print('已设置远程描述');
      
    } catch (e) {
      _handleError('处理 Answer 失败: $e');
    }
  }
  
  /// 获取可用视频列表
  Future<List<String>> getAvailableVideos() async {
    try {
      if (!_isConnected) {
        await _connectSocket();
      }
      
      final completer = Completer<List<String>>();
      
      _socket!.once('videos_list', (data) {
        List<String> videos = List<String>.from(data['videos'] ?? []);
        completer.complete(videos);
      });
      
      _socket!.emit('get_videos', {});
      
      return await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => [],
      );
      
    } catch (e) {
      _handleError('获取视频列表失败: $e');
      return [];
    }
  }
  
  /// 关闭连接
  Future<void> _closeConnection() async {
    try {
      if (_peerConnection != null) {
        await _peerConnection!.close();
        _peerConnection = null;
      }
      
      _remoteStream = null;
      
    } catch (e) {
      print('关闭连接失败: $e');
    }
  }
  
  /// 释放资源
  Future<void> dispose() async {
    try {
      await _closeConnection();
      
      if (_remoteRenderer != null) {
        await _remoteRenderer!.dispose();
        _remoteRenderer = null;
      }
      
      if (_socket != null) {
        _socket!.disconnect();
        _socket!.dispose();
        _socket = null;
      }
      
      _isConnected = false;
      _isStreaming = false;
      
    } catch (e) {
      print('释放资源失败: $e');
    }
  }
  
  /// 错误处理
  void _handleError(String message) {
    print('WebRTC 错误: $message');
    onError?.call(message);
  }
  
  /// 获取远程视频渲染器
  RTCVideoRenderer? getRemoteRenderer() {
    return _remoteRenderer;
  }
}
