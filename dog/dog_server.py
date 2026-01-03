from flask import Flask, request, jsonify, send_from_directory, stream_with_context, Response, abort
from flask_cors import CORS
import threading
import time
import json
import os
from datetime import datetime, timedelta
import logging
from werkzeug.utils import secure_filename
from threading import Lock
from queue import Queue
import cv2
import re

# 配置日志
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class DogServer:
    def __init__(self):
        print("初始化dog服务器")
        self.app = Flask(__name__)
        
        # 配置跨域请求
        CORS(self.app)
        
        # 使用绝对路径以避免 CWD (当前工作目录) 不同导致的问题
        # .../DogApp2/dog
        current_dir = os.path.dirname(os.path.abspath(__file__))
        # .../DogApp2
        root_dir = os.path.dirname(current_dir)

        # 服务器配置
        self.UPLOAD_FOLDER = os.path.join(root_dir, 'uploads')
        self.ASSETS_FOLDER = os.path.join(current_dir, 'assets')
        self.ALLOWED_IMAGE_EXTENSIONS = {'png', 'jpg', 'jpeg', 'gif', 'bmp'}
        self.MAX_FILE_SIZE = 16 * 1024 * 1024  # 16MB
        
        # Flask应用配置
        self.app.config['UPLOAD_FOLDER'] = self.UPLOAD_FOLDER
        self.app.config['ASSETS_FOLDER'] = self.ASSETS_FOLDER
        self.app.config['MAX_CONTENT_LENGTH'] = self.MAX_FILE_SIZE
        
        # 创建上传目录
        os.makedirs(self.UPLOAD_FOLDER, exist_ok=True)
        os.makedirs(self.ASSETS_FOLDER, exist_ok=True)
        
        # 线程锁用于文件操作
        self.file_lock = Lock()
        
        # 服务器状态和识别结果
        self.current_status = "idle"
        self.recognition_results = []
        
        # 视频直播相关
        self.video_stream = None
        self.is_streaming = False
        self.stream_lock = Lock()
        self.video_stream_path = None  # 当前播放的视频路径
        self.video_folder = os.path.join(self.ASSETS_FOLDER, 'videos')
        os.makedirs(self.video_folder, exist_ok=True)
        # 新增：内存中的对话历史
        self.dialog_history = [
            {
                'id': 0,
                'role': 'user',
                'message': '你好',
                'timestamp': "2023-10-05T14:20:00Z",
                'type': 'none',
            },
            {
                'id': 1,
                'role': 'assistant',
                'message': '你好！有什么我可以帮助你的吗？',
                'timestamp': "2023-10-05T14:20:00Z",
                'type': 'none',
            },
        ]

        # 通知订阅（SSE）：保存每个订阅者的队列（支持按 client_id 定向推送）
        self.notification_subscribers = {}  # client_id -> Queue
        self.notification_lock = Lock()

        # 通知历史与确认（用于双向通知链路）
        self.notification_history = []
        self.notification_history_lock = Lock()
        self.notification_next_id = 1

        # 简单账号存储（明文，保存在 dog/users.json）
        self.users_file_path = os.path.join(current_dir, 'users.json')

        # 日程提醒推送相关
        self.schedule_notifier_stop = threading.Event()
        self.schedule_last_trigger = {}
        self.schedule_notifier_thread = threading.Thread(
            target=self._schedule_notifier_loop, daemon=True
        )

        # 设置路由
        self.setup_routes()

        # 启动日程提醒检测线程
        self.schedule_notifier_thread.start()
    
    def allowed_file(self, filename):
        """检查文件扩展名是否允许[2,3]"""
        return '.' in filename and \
               filename.rsplit('.', 1)[1].lower() in self.ALLOWED_IMAGE_EXTENSIONS
    
    def save_json_data(self, data, filename):
        """安全地保存JSON数据"""
        try:
            with self.file_lock:
                with open(os.path.join(self.app.config['UPLOAD_FOLDER'], filename), 'w', encoding='utf-8') as f:
                    json.dump(data, f, ensure_ascii=False, indent=4)
            return True
        except Exception as e:
            logger.error(f"保存JSON数据失败: {e}")
            return False
    
    def load_json_data(self, filename):
        """安全地加载JSON数据"""
        try:
            with self.file_lock:
                filepath = os.path.join(self.app.config['UPLOAD_FOLDER'], filename)
                if os.path.exists(filepath):
                    with open(filepath, 'r', encoding='utf-8') as f:
                        return json.load(f)
            return None
        except Exception as e:
            logger.error(f"加载JSON数据失败: {e}")
            return None
    
    def load_assets_json(self, filename):
        """加载assets目录下的JSON文件"""
        try:
            with self.file_lock:
                filepath = os.path.join(self.ASSETS_FOLDER, filename)
                if os.path.exists(filepath):
                    with open(filepath, 'r', encoding='utf-8') as f:
                        return json.load(f)
            return {}
        except Exception as e:
            logger.error(f"加载assets JSON数据失败: {e}")
            return {}
    
    def save_assets_json(self, data, filename):
        """保存JSON数据到assets目录"""
        try:
            with self.file_lock:
                filepath = os.path.join(self.ASSETS_FOLDER, filename)
                with open(filepath, 'w', encoding='utf-8') as f:
                    json.dump(data, f, ensure_ascii=False, indent=2)
            return True
        except Exception as e:
            logger.error(f"保存assets JSON数据失败: {e}")
            return False

    # ========== 简易账号存储（明文，仅演示用途） ==========
    def load_users(self):
        try:
            with self.file_lock:
                if os.path.exists(self.users_file_path):
                    with open(self.users_file_path, 'r', encoding='utf-8') as f:
                        data = json.load(f)
                        if isinstance(data, list):
                            return {'users': data}
                        if isinstance(data, dict) and 'users' in data:
                            return {'users': data.get('users', [])}
        except Exception as e:
            logger.error(f"加载用户数据失败: {e}")
        return {'users': []}

    def save_users(self, users):
        try:
            with self.file_lock:
                with open(self.users_file_path, 'w', encoding='utf-8') as f:
                    json.dump(users, f, ensure_ascii=False, indent=4)
            return True
        except Exception as e:
            logger.error(f"保存用户数据失败: {e}")
            return False
    
    def get_video_stream_generator(self, video_path):
        """生成视频流，循环播放"""
        try:
            cap = cv2.VideoCapture(video_path)
            if not cap.isOpened():
                logger.error(f"无法打开视频文件: {video_path}")
                return
            
            while self.is_streaming:
                ret, frame = cap.read()
                if not ret:
                    # 视频结束，从头开始循环播放
                    cap.set(cv2.CAP_PROP_POS_FRAMES, 0)
                    ret, frame = cap.read()
                    if not ret:
                        break
                
                # 编码帧为JPEG
                ret, buffer = cv2.imencode('.jpg', frame)
                if ret:
                    frame_bytes = buffer.tobytes()
                    yield (b'--frame\r\n'
                           b'Content-Type: image/jpeg\r\n'
                           b'Content-Length: ' + str(len(frame_bytes)).encode() + b'\r\n\r\n' +
                           frame_bytes + b'\r\n')
                
                # 控制帧率，约30FPS
                time.sleep(0.033)
            
            cap.release()
        except Exception as e:
            logger.error(f"视频流处理错误: {e}")
    
    def start_video_stream(self, video_filename):
        """启动视频直播"""
        try:
            video_path = os.path.join(self.video_folder, video_filename)
            if not os.path.exists(video_path):
                logger.error(f"视频文件不存在: {video_path}")
                return False
            
            with self.stream_lock:
                if self.is_streaming:
                    return True  # 已在直播
                
                self.is_streaming = True
                self.video_stream_path = video_path
            
            logger.info(f"启动视频直播: {video_path}")
            return True
        except Exception as e:
            logger.error(f"启动视频直播失败: {e}")
            return False
    
    def stop_video_stream(self):
        """停止视频直播"""
        try:
            with self.stream_lock:
                self.is_streaming = False
            logger.info("停止视频直播")
            return True
        except Exception as e:
            logger.error(f"停止视频直播失败: {e}")
            return False

    def broadcast_notification(self, data: dict):
        """推送通知。

        约定：
        - data['to'] == 'all' 或 None: 广播
        - data['to'] == <client_id>: 定向给某一端
        - data['to'] == {'any_of': [id1,id2]}: 多播（任一匹配都发送）
        """
        try:
            # 记录历史（最多 200 条），并分配 id
            with self.notification_history_lock:
                if 'id' not in data:
                    data['id'] = self.notification_next_id
                    self.notification_next_id += 1
                self.notification_history.append(data)
                if len(self.notification_history) > 200:
                    self.notification_history = self.notification_history[-200:]

            target = data.get('to')
            with self.notification_lock:
                subs = dict(self.notification_subscribers)

            # 广播
            if target is None or target == 'all':
                for _, q in subs.items():
                    try:
                        q.put_nowait(data)
                    except Exception:
                        continue
                return

            # 多播
            if isinstance(target, dict) and isinstance(target.get('any_of'), list):
                for cid in target.get('any_of'):
                    q = subs.get(str(cid))
                    if q is None:
                        continue
                    try:
                        q.put_nowait(data)
                    except Exception:
                        continue
                return

            # 定向
            q = subs.get(str(target))
            if q is not None:
                try:
                    q.put_nowait(data)
                except Exception:
                    pass
        except Exception as e:
            logger.error(f"推送通知失败: {e}")

    def _schedule_notifier_loop(self):
        """定期检查日程，时间到点时推送通知"""
        while not self.schedule_notifier_stop.is_set():
            try:
                schedules = self.load_assets_json('reminders.json').get('reminders', [])
                now = datetime.now()
                today_str = now.strftime('%Y-%m-%d')

                for item in schedules:
                    time_str = item.get('time', '')
                    event = item.get('event', '')
                    schedule_id = item.get('id')

                    # 解析 HH:MM
                    try:
                        hh, mm = time_str.split(':')[:2]
                        hh = int(hh)
                        mm = int(mm)
                    except Exception:
                        continue

                    scheduled_dt = now.replace(hour=hh, minute=mm, second=0, microsecond=0)

                    # 如果日程时间已经过了 10 分钟，跳过
                    if now - scheduled_dt > timedelta(minutes=10):
                        continue

                    # 仅在时间到且还未推送过时提醒
                    key = f"{today_str}-{schedule_id}"
                    if self.schedule_last_trigger.get(key) == today_str:
                        continue

                    if scheduled_dt <= now <= scheduled_dt + timedelta(minutes=1):
                        notif = {
                            'type': 'schedule',
                            'timestamp': now.isoformat(),
                            'message': f"日程提醒：{event} ({time_str})",
                            'payload': {
                                'schedule_id': schedule_id,
                                'time': time_str,
                                'event': event,
                            }
                        }
                        self.broadcast_notification(notif)
                        self.schedule_last_trigger[key] = today_str
            except Exception as e:
                logger.error(f"日程提醒检测失败: {e}")

            # 间隔 30 秒检查一次
            self.schedule_notifier_stop.wait(30)
    
    def setup_routes(self):
        """设置所有API路由"""
        
        # 根路径，返回服务器状态
        @self.app.route('/')
        def index():
            return jsonify({
                'status': 'running',
                'service': 'Dog Control Server',
                'timestamp': datetime.now().isoformat()
            })

        # ========== 简单登录/注册（明文存储，仅演示） ==========
        @self.app.route('/auth/register', methods=['POST'])
        def register_user():
            try:
                data = request.get_json() or {}
                phone = (data.get('phone') or '').strip()
                password = (data.get('password') or '').strip()

                if not phone or not password:
                    return jsonify({'message': '手机号和密码不能为空'}), 400

                if not re.fullmatch(r'^1\d{10}$', phone):
                    return jsonify({'message': '手机号格式不正确，需要11位数字且以1开头'}), 400

                if len(password) < 6:
                    return jsonify({'message': '密码长度需至少6位'}), 400

                users = self.load_users()
                if any(u.get('phone') == phone for u in users['users']):
                    return jsonify({'message': '用户已存在'}), 409

                users['users'].append({
                    'phone': phone,
                    'password': password,
                    'created_at': datetime.now().isoformat()
                })

                if self.save_users(users):
                    return jsonify({'message': '注册成功', 'phone': phone}), 200
                return jsonify({'message': '保存失败'}), 500
            except Exception as e:
                logger.error(f"注册失败: {e}")
                return jsonify({'message': '服务器错误'}), 500

        @self.app.route('/auth/logout', methods=['POST'])
        def logout_user():
            # 简单返回成功，实际会话由前端本地管理
            return jsonify({'message': '已退出登录'}), 200

        @self.app.route('/auth/login', methods=['POST'])
        def login_user():
            try:
                data = request.get_json() or {}
                phone = (data.get('phone') or '').strip()
                password = (data.get('password') or '').strip()

                if not phone or not password:
                    return jsonify({'message': '手机号和密码不能为空'}), 400

                users = self.load_users()['users']
                matched = next((u for u in users if u.get('phone') == phone and u.get('password') == password), None)
                if matched:
                    return jsonify({'message': '登录成功', 'phone': phone}), 200
                return jsonify({'message': '手机号或密码错误'}), 401
            except Exception as e:
                logger.error(f"登录失败: {e}")
                return jsonify({'message': '服务器错误'}), 500
        
        # 状态查询路由
        @self.app.route('/status')
        def get_status():
            return jsonify({
                'status': self.current_status,
                'timestamp': datetime.now().isoformat(),
                'battery': {'level': 80, 'status': 'charging'},
                'location': {'room': 'A101', 'coordinates': '10.5, 20.3'},
                'dialog_history': self.dialog_history,
            })
        
        # 识别结果查询路由
        @self.app.route('/recognition_results')
        def get_recognition_results():
            return jsonify(self.recognition_results)
        
        # 更新识别结果路由
        @self.app.route('/update_recognition', methods=['POST'])
        def update_recognition():
            data = request.json
            result = {
                'type': data.get('type', 'unknown'),
                'confidence': data.get('confidence', 0),
                'timestamp': datetime.now().isoformat(),
                'data': data.get('data', {})
            }
            self.recognition_results.append(result)
            # 只保留最近50条记录
            if len(self.recognition_results) > 50:
                self.recognition_results = self.recognition_results[-50:]
            return jsonify({'message': '识别结果更新成功'})
        
        # 更新家庭信息路由
        @self.app.route('/update_info', methods=['POST'])
        def update_family_info():
            try:
                family_info = request.get_json()
                if not family_info:
                    return jsonify({'message': '未接收到有效的JSON数据'}), 400

                # 验证必要字段
                required_fields = ['address', 'members']
                for field in required_fields:
                    if field not in family_info:
                        return jsonify({'message': f'缺少必要字段: {field}'}), 400

                if self.save_json_data(family_info, 'family_info.json'):
                    logger.info(f"[{datetime.now()}] 家庭信息已更新: {family_info}")
                    return jsonify({
                        'message': '家庭信息更新成功!', 
                        'received_data': family_info
                    }), 200
                else:
                    return jsonify({'message': '保存数据失败'}), 500

            except Exception as e:
                logger.error(f"处理家庭信息时出错: {e}")
                return jsonify({'message': '服务器内部错误'}), 500
        
        # 获取家庭信息路由
        @self.app.route('/get_family_info', methods=['GET'])
        def get_family_info():
            try:
                family_info = self.load_assets_json('family_info.json')
                if family_info:
                    return jsonify(family_info), 200
                else:
                    return jsonify({'message': '未找到家庭信息'}), 404
            except Exception as e:
                logger.error(f"获取家庭信息时出错: {e}")
                return jsonify({'message': '服务器内部错误'}), 500
        
        # ========== 问答数据管理 API (记忆库) ==========
        @self.app.route('/get_family_questions', methods=['GET'])
        def get_family_questions():
            """获取所有问答数据"""
            try:
                family_info = self.load_assets_json('family_info.json')
                questions = family_info.get('questions', [])
                return jsonify(questions), 200
            except Exception as e:
                logger.error(f"获取问答数据时出错: {e}")
                return jsonify({'message': '服务器内部错误'}), 500
        
        @self.app.route('/update_family_question', methods=['POST'])
        def update_family_question():
            """更新或添加问答数据"""
            try:
                data = request.get_json()
                if not data:
                    return jsonify({'message': '未接收到有效数据'}), 400
                
                question_id = data.get('question_id')  # 可以是索引或None（新增）
                question_text = data.get('question', '')
                answer_text = data.get('answer', '')
                command = data.get('command', '')
                audio_file = data.get('audio_file', '')
                
                if not question_text or not answer_text:
                    return jsonify({'message': '问题和答案不能为空'}), 400
                
                # 加载现有数据
                family_info = self.load_assets_json('family_info.json')
                if 'questions' not in family_info:
                    family_info['questions'] = []
                
                # 创建新的问答对象
                new_question = {
                    'question': question_text,
                    'answer': answer_text,
                    'update_time': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
                    'audio_file': audio_file or '',
                    'command': command or ''
                }
                
                # 如果有question_id，更新现有问题；否则添加新问题
                if question_id is not None and isinstance(question_id, int) and 0 <= question_id < len(family_info['questions']):
                    family_info['questions'][question_id] = new_question
                else:
                    family_info['questions'].append(new_question)
                
                if self.save_assets_json(family_info, 'family_info.json'):
                    logger.info(f"[{datetime.now()}] 问答数据已更新")
                    return jsonify({'message': '问答数据更新成功', 'question_id': len(family_info['questions']) - 1}), 200
                else:
                    return jsonify({'message': '保存失败'}), 500
                    
            except Exception as e:
                logger.error(f"更新问答数据时出错: {e}")
                return jsonify({'message': '服务器内部错误'}), 500
        
        @self.app.route('/delete_family_question', methods=['POST'])
        def delete_family_question():
            """删除问答数据"""
            try:
                data = request.get_json()
                question_id = data.get('question_id')
                
                if question_id is None:
                    return jsonify({'message': '缺少question_id字段'}), 400
                
                family_info = self.load_assets_json('family_info.json')
                if 'questions' not in family_info:
                    return jsonify({'message': '未找到问答数据'}), 404
                
                if isinstance(question_id, int) and 0 <= question_id < len(family_info['questions']):
                    del family_info['questions'][question_id]
                    if self.save_assets_json(family_info, 'family_info.json'):
                        return jsonify({'message': '删除成功'}), 200
                    else:
                        return jsonify({'message': '保存失败'}), 500
                else:
                    return jsonify({'message': '无效的question_id'}), 400
                    
            except Exception as e:
                logger.error(f"删除问答数据时出错: {e}")
                return jsonify({'message': '服务器内部错误'}), 500
        
        # 图片上传路由
        @self.app.route('/upload_pic', methods=['POST'])
        def upload_picture():
            try:
                if 'file' not in request.files:
                    return jsonify({'message': '请求中未包含文件'}), 400

                file = request.files['file']
                if file.filename == '':
                    return jsonify({'message': '未选择文件'}), 400

                if file and self.allowed_file(file.filename):
                    # 生成安全文件名
                    filename = secure_filename(file.filename)
                    # 添加时间戳避免重名
                    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                    name, ext = os.path.splitext(filename)
                    filename = f"{name}_{timestamp}{ext}"
                    
                    save_path = os.path.join(self.app.config['UPLOAD_FOLDER'], filename)
                    file.save(save_path)

                    # 记录上传信息
                    upload_info = {
                        'filename': filename,
                        'original_name': file.filename,
                        'upload_time': datetime.now().isoformat(),
                        'size': os.path.getsize(save_path)
                    }
                    
                    # 保存上传记录
                    uploads = self.load_json_data('uploads.json') or []
                    uploads.append(upload_info)
                    self.save_json_data(uploads, 'uploads.json')

                    logger.info(f"[{datetime.now()}] 图片已保存: {save_path}")
                    return jsonify({
                        'message': '文件上传成功!', 
                        'file_path': filename,
                        'info': upload_info
                    }), 200
                else:
                    return jsonify({'message': '不支持的文件类型'}), 400

            except Exception as e:
                logger.error(f"处理图片上传时出错: {e}")
                return jsonify({'message': '服务器内部错误'}), 500
        
        # 获取图片路由
        @self.app.route('/images/<filename>')
        def get_image(filename):
            try:
                return send_from_directory(self.app.config['UPLOAD_FOLDER'], filename)
            except FileNotFoundError:
                return jsonify({'message': '图片未找到'}), 404

        # 访问 assets 下的静态资源（含记忆库图片）
        @self.app.route('/assets/<path:filename>')
        def get_asset(filename):
            try:
                safe_path = os.path.normpath(filename)
                if safe_path.startswith('..'):
                    return abort(400)
                return send_from_directory(self.app.config['ASSETS_FOLDER'], safe_path)
            except FileNotFoundError:
                return jsonify({'message': '资源未找到'}), 404
        
        # GPS数据上传路由
        @self.app.route('/upload_gps', methods=['POST'])
        def upload_gps():
            try:
                gps_data = request.get_json()
                if not gps_data:
                    return jsonify({'message': '未接收到有效的GPS数据'}), 400

                # 验证必要字段
                required_fields = ['lat', 'lon']
                for field in required_fields:
                    if field not in gps_data:
                        return jsonify({'message': f'缺少必要GPS字段: {field}'}), 400

                # 添加时间戳
                gps_data['server_received_time'] = datetime.now().isoformat()
                
                # 保存GPS记录
                gps_history = self.load_json_data('gps_history.json') or []
                gps_history.append(gps_data)
                
                # 只保留最近100条记录
                if len(gps_history) > 100:
                    gps_history = gps_history[-100:]
                
                if self.save_json_data(gps_history, 'gps_history.json'):
                    logger.info(f"[{datetime.now()}] 接收到GPS数据 - 纬度: {gps_data['lat']}, 经度: {gps_data['lon']}")
                    
                    # 这里可以添加机器狗导航逻辑
                    # 例如：robot_controller.navigate_to(gps_data['lat'], gps_data['lon'])
                    
                    return jsonify({
                        'message': 'GPS数据接收成功!', 
                        'received_data': gps_data
                    }), 200
                else:
                    return jsonify({'message': '保存GPS数据失败'}), 500

            except Exception as e:
                logger.error(f"处理GPS数据时出错: {e}")
                return jsonify({'message': '服务器内部错误'}), 500
        
        # 获取GPS历史记录路由
        @self.app.route('/get_gps_history', methods=['GET'])
        def get_gps_history():
            try:
                gps_history = self.load_json_data('gps_history.json') or []
                return jsonify(gps_history), 200
            except Exception as e:
                logger.error(f"获取GPS历史时出错: {e}")
                return jsonify({'message': '服务器内部错误'}), 500
        
        # ========== 人脸信息管理 API ==========
        @self.app.route('/get_face_info', methods=['GET'])
        def get_face_info():
            """获取所有人脸信息"""
            try:
                face_info = self.load_assets_json('face_info.json')
                return jsonify(face_info), 200
            except Exception as e:
                logger.error(f"获取人脸信息时出错: {e}")
                return jsonify({'message': '服务器内部错误'}), 500
        
        @self.app.route('/update_face_info', methods=['POST'])
        def update_face_info():
            """更新或添加人脸信息"""
            try:
                data = request.get_json()
                if not data:
                    return jsonify({'message': '未接收到有效数据'}), 400
                
                face_id = data.get('face_id')
                description = data.get('description', '')
                audio_file = data.get('audio_file', '')
                
                if not face_id:
                    return jsonify({'message': '缺少face_id字段'}), 400
                
                # 加载现有数据
                face_info = self.load_assets_json('face_info.json')
                
                # 更新或添加
                face_info[face_id] = {
                    'description': description,
                    'update_time': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
                    'audio_file': audio_file
                }
                
                if self.save_assets_json(face_info, 'face_info.json'):
                    logger.info(f"[{datetime.now()}] 人脸信息已更新: {face_id}")
                    return jsonify({'message': '人脸信息更新成功', 'face_id': face_id}), 200
                else:
                    return jsonify({'message': '保存失败'}), 500
                    
            except Exception as e:
                logger.error(f"更新人脸信息时出错: {e}")
                return jsonify({'message': '服务器内部错误'}), 500
        
        @self.app.route('/delete_face_info', methods=['POST'])
        def delete_face_info():
            """删除人脸信息"""
            try:
                data = request.get_json()
                face_id = data.get('face_id')
                
                if not face_id:
                    return jsonify({'message': '缺少face_id字段'}), 400
                
                face_info = self.load_assets_json('face_info.json')
                if face_id in face_info:
                    del face_info[face_id]
                    if self.save_assets_json(face_info, 'face_info.json'):
                        return jsonify({'message': '删除成功'}), 200
                    else:
                        return jsonify({'message': '保存失败'}), 500
                else:
                    return jsonify({'message': '未找到该人脸信息'}), 404
                    
            except Exception as e:
                logger.error(f"删除人脸信息时出错: {e}")
                return jsonify({'message': '服务器内部错误'}), 500
        
        # 上传人脸照片到face_detector目录
        @self.app.route('/upload_face_image', methods=['POST'])
        def upload_face_image():
            """上传人脸照片到face_detector/known_faces目录"""
            try:
                if 'file' not in request.files:
                    return jsonify({'message': '请求中未包含文件'}), 400
                
                file = request.files['file']
                face_id = request.form.get('face_id', '')
                
                if file.filename == '':
                    return jsonify({'message': '未选择文件'}), 400
                
                if not face_id:
                    return jsonify({'message': '缺少face_id参数'}), 400
                
                if file and self.allowed_file(file.filename):
                    # 确保face_id格式正确
                    if not face_id.startswith('face_'):
                        face_id = f"face_{face_id}"
                    
                    # 保存到face_detector/known_faces目录
                    face_dir = os.path.join(self.ASSETS_FOLDER, 'face_detector', 'known_faces')
                    os.makedirs(face_dir, exist_ok=True)
                    
                    # 使用face_id作为文件名
                    ext = os.path.splitext(file.filename)[1]
                    filename = f"{face_id}{ext}"
                    save_path = os.path.join(face_dir, filename)
                    file.save(save_path)
                    
                    logger.info(f"[{datetime.now()}] 人脸照片已保存: {save_path}")
                    return jsonify({
                        'message': '人脸照片上传成功!',
                        'face_id': face_id,
                        'file_path': filename
                    }), 200
                else:
                    return jsonify({'message': '不支持的文件类型'}), 400
                    
            except Exception as e:
                logger.error(f"处理人脸照片上传时出错: {e}")
                return jsonify({'message': '服务器内部错误'}), 500
        
        # ========== 药品信息管理 API ==========
        @self.app.route('/get_qr_code_info', methods=['GET'])
        def get_qr_code_info():
            """获取所有药品信息"""
            try:
                qr_info = self.load_assets_json('qr_code_info.json')
                return jsonify(qr_info), 200
            except Exception as e:
                logger.error(f"获取药品信息时出错: {e}")
                return jsonify({'message': '服务器内部错误'}), 500
        
        @self.app.route('/update_qr_code_info', methods=['POST'])
        def update_qr_code_info():
            """更新或添加药品信息"""
            try:
                data = request.get_json()
                if not data:
                    return jsonify({'message': '未接收到有效数据'}), 400
                
                med_id = data.get('med_id')
                description = data.get('description', '')
                audio_file = data.get('audio_file', '')
                
                if not med_id:
                    return jsonify({'message': '缺少med_id字段'}), 400
                
                # 加载现有数据
                qr_info = self.load_assets_json('qr_code_info.json')
                
                # 更新或添加
                qr_info[med_id] = {
                    'description': description,
                    'update_time': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
                    'audio_file': audio_file
                }
                
                if self.save_assets_json(qr_info, 'qr_code_info.json'):
                    logger.info(f"[{datetime.now()}] 药品信息已更新: {med_id}")
                    return jsonify({'message': '药品信息更新成功', 'med_id': med_id}), 200
                else:
                    return jsonify({'message': '保存失败'}), 500
                    
            except Exception as e:
                logger.error(f"更新药品信息时出错: {e}")
                return jsonify({'message': '服务器内部错误'}), 500
        
        @self.app.route('/delete_qr_code_info', methods=['POST'])
        def delete_qr_code_info():
            """删除药品信息"""
            try:
                data = request.get_json()
                med_id = data.get('med_id')
                
                if not med_id:
                    return jsonify({'message': '缺少med_id字段'}), 400
                
                qr_info = self.load_assets_json('qr_code_info.json')
                if med_id in qr_info:
                    del qr_info[med_id]
                    if self.save_assets_json(qr_info, 'qr_code_info.json'):
                        return jsonify({'message': '删除成功'}), 200
                    else:
                        return jsonify({'message': '保存失败'}), 500
                else:
                    return jsonify({'message': '未找到该药品信息'}), 404
                    
            except Exception as e:
                logger.error(f"删除药品信息时出错: {e}")
                return jsonify({'message': '服务器内部错误'}), 500
        
        # ========== 照片信息管理 API (记忆库) ==========
        @self.app.route('/get_photo_info', methods=['GET'])
        def get_photo_info():
            """获取所有照片信息"""
            try:
                photo_info = self.load_assets_json('photo_info.json')
                return jsonify(photo_info), 200
            except Exception as e:
                logger.error(f"获取照片信息时出错: {e}")
                return jsonify({'message': '服务器内部错误'}), 500
        
        @self.app.route('/update_photo_info', methods=['POST'])
        def update_photo_info():
            """更新或添加照片信息"""
            try:
                data = request.get_json()
                if not data:
                    return jsonify({'message': '未接收到有效数据'}), 400
                
                photo_id = data.get('photo_id')
                description = data.get('description', '')
                audio_file = data.get('audio_file', '')
                title = data.get('title', '')
                event_date = data.get('event_date', '')
                image_file = data.get('image_file', '')
                location = data.get('location', '')
                tags = data.get('tags', [])
                people = data.get('people', [])
                emotion = data.get('emotion', '')

                if isinstance(tags, str):
                    tags = [t.strip() for t in tags.split(',') if t.strip()]
                if isinstance(people, str):
                    people = [p.strip() for p in people.split(',') if p.strip()]
                
                if not photo_id:
                    return jsonify({'message': '缺少photo_id字段'}), 400
                
                # 加载现有数据
                photo_info = self.load_assets_json('photo_info.json')
                existing = photo_info.get(photo_id, {})
                
                # 更新或添加
                photo_info[photo_id] = {
                    'title': title or existing.get('title', ''),
                    'description': description or existing.get('description', ''),
                    'event_date': event_date or existing.get('event_date', ''),
                    'update_time': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
                    'image_file': image_file or existing.get('image_file', ''),
                    'audio_file': audio_file or existing.get('audio_file', ''),
                    'location': location or existing.get('location', ''),
                    'tags': tags or existing.get('tags', []),
                    'people': people or existing.get('people', []),
                    'emotion': emotion or existing.get('emotion', '')
                }
                
                if self.save_assets_json(photo_info, 'photo_info.json'):
                    logger.info(f"[{datetime.now()}] 照片信息已更新: {photo_id}")
                    return jsonify({'message': '照片信息更新成功', 'photo_id': photo_id}), 200
                else:
                    return jsonify({'message': '保存失败'}), 500
                    
            except Exception as e:
                logger.error(f"更新照片信息时出错: {e}")
                return jsonify({'message': '服务器内部错误'}), 500
        
        @self.app.route('/delete_photo_info', methods=['POST'])
        def delete_photo_info():
            """删除照片信息"""
            try:
                data = request.get_json()
                photo_id = data.get('photo_id')
                
                if not photo_id:
                    return jsonify({'message': '缺少photo_id字段'}), 400
                
                photo_info = self.load_assets_json('photo_info.json')
                if photo_id in photo_info:
                    del photo_info[photo_id]
                    if self.save_assets_json(photo_info, 'photo_info.json'):
                        return jsonify({'message': '删除成功'}), 200
                    else:
                        return jsonify({'message': '保存失败'}), 500
                else:
                    return jsonify({'message': '未找到该照片信息'}), 404
                    
            except Exception as e:
                logger.error(f"删除照片信息时出错: {e}")
                return jsonify({'message': '服务器内部错误'}), 500
        
        # 上传记忆库照片到photo_detector目录
        @self.app.route('/upload_photo_image', methods=['POST'])
        def upload_photo_image():
            """上传照片到photo_detector目录"""
            try:
                if 'file' not in request.files:
                    return jsonify({'message': '请求中未包含文件'}), 400
                
                file = request.files['file']
                photo_id = request.form.get('photo_id', '')
                
                if file.filename == '':
                    return jsonify({'message': '未选择文件'}), 400
                
                if not photo_id:
                    return jsonify({'message': '缺少photo_id参数'}), 400
                
                if file and self.allowed_file(file.filename):
                    # 确保photo_id格式正确
                    if not photo_id.startswith('photo_'):
                        photo_id = f"photo_{photo_id}"
                    
                    # 保存到photo_detector目录
                    photo_dir = os.path.join(self.ASSETS_FOLDER, 'photo_detector')
                    os.makedirs(photo_dir, exist_ok=True)
                    
                    # 使用photo_id作为文件名
                    ext = os.path.splitext(file.filename)[1]
                    filename = f"{photo_id}{ext}"
                    save_path = os.path.join(photo_dir, filename)
                    file.save(save_path)
                    
                    logger.info(f"[{datetime.now()}] 照片已保存: {save_path}")
                    return jsonify({
                        'message': '照片上传成功!',
                        'photo_id': photo_id,
                        'file_path': filename,
                        'asset_path': f"photo_detector/{filename}"
                    }), 200
                else:
                    return jsonify({'message': '不支持的文件类型'}), 400
                    
            except Exception as e:
                logger.error(f"处理照片上传时出错: {e}")
                return jsonify({'message': '服务器内部错误'}), 500
        
        # 新增：发送指令接口，供 Flutter/Kivy DogScreen 调用
        @self.app.route('/send_command', methods=['POST'])
        def send_command():
            try:
                data = request.get_json() or {}
                cmd = data.get('command', '')
                ts = data.get('timestamp') or datetime.now().isoformat()

                # 将指令加入对话历史
                new_id = (self.dialog_history[-1]['id'] + 1) if self.dialog_history else 0
                self.dialog_history.append({
                    'id': new_id,
                    'role': 'user',
                    'message': cmd,
                    'timestamp': ts,
                    'type': 'command',
                })

                # 简单模拟机器人回复
                reply_id = new_id + 1
                self.dialog_history.append({
                    'id': reply_id,
                    'role': 'assistant',
                    'message': f'收到指令：{cmd}',
                    'timestamp': datetime.now().isoformat(),
                    'type': 'reply',
                })

                # 保留最近 50 条
                if len(self.dialog_history) > 50:
                    self.dialog_history = self.dialog_history[-50:]

                return jsonify({'message': '指令已接收'}), 200
            except Exception as e:
                logger.error(f"处理指令时出错: {e}")
                return jsonify({'message': '服务器内部错误'}), 500

        # 新增：返回充电接口
        @self.app.route('/return_home', methods=['POST'])
        def return_home():
            try:
                # 在真实系统中这里应调用机器人回充逻辑
                self.current_status = 'returning_home'
                logger.info(f"[{datetime.now()}] 收到返回充电指令")

                new_id = (self.dialog_history[-1]['id'] + 1) if self.dialog_history else 0
                self.dialog_history.append({
                    'id': new_id,
                    'role': 'assistant',
                    'message': '已收到返回充电指令，正在前往充电座。',
                    'timestamp': datetime.now().isoformat(),
                    'type': 'reply',
                })
                if len(self.dialog_history) > 50:
                    self.dialog_history = self.dialog_history[-50:]

                return jsonify({'message': '返回充电指令已接收'}), 200
            except Exception as e:
                logger.error(f"处理返回充电指令时出错: {e}")
                return jsonify({'message': '服务器内部错误'}), 500

        # 新增：SOS 警报接口
        @self.app.route('/sos_alert', methods=['POST'])
        def sos_alert():
            try:
                data = request.get_json() or {}
                logger.warning(f"[{datetime.now()}] 收到SOS: {data}")
                self.broadcast_notification({
                    'type': 'sos',
                    'timestamp': datetime.now().isoformat(),
                    'payload': data,
                    'message': data.get('message', '患者发出了SOS求助')
                })
                return jsonify({'message': 'SOS已接收'}), 200
            except Exception as e:
                logger.error(f"处理SOS时出错: {e}")
                return jsonify({'message': '服务器内部错误'}), 500

        @self.app.route('/notifications/subscribe')
        def subscribe_notifications():
            """基于SSE的通知订阅通道"""
            client_id = request.args.get('client_id') or 'unknown'
            q = Queue()
            logger.info(f"[notifications] SSE subscribe client_id={client_id}")
            with self.notification_lock:
                self.notification_subscribers[client_id] = q
                logger.info(f"[notifications] subscribers={len(self.notification_subscribers)}")

            def gen():
                # 首次推送一条hello保持兼容
                yield f"data: {json.dumps({'type': 'hello', 'client_id': client_id}, ensure_ascii=False)}\n\n"
                try:
                    while True:
                        try:
                            item = q.get(timeout=25)
                            logger.info(f"[notifications] deliver to={client_id} type={item.get('type')} id={item.get('id')}")
                            yield f"data: {json.dumps(item, ensure_ascii=False)}\n\n"
                        except Exception:
                            # 心跳，保持连接
                            logger.debug(f"[notifications] ping to={client_id}")
                            yield 'data: {"type":"ping"}\n\n'
                finally:
                    with self.notification_lock:
                        if self.notification_subscribers.get(client_id) is q:
                            del self.notification_subscribers[client_id]
                        logger.info(f"[notifications] SSE disconnect client_id={client_id} subscribers={len(self.notification_subscribers)}")

            headers = {
                'Content-Type': 'text/event-stream',
                'Cache-Control': 'no-cache',
                'X-Accel-Buffering': 'no',
                'Connection': 'keep-alive',
                'Access-Control-Allow-Origin': '*'
            }
            return Response(stream_with_context(gen()), headers=headers)

        @self.app.route('/notifications/history', methods=['GET'])
        def notifications_history():
            """拉取最近通知历史（用于重连补偿与通知中心列表）"""
            try:
                limit = int(request.args.get('limit', 50))
                limit = max(1, min(limit, 200))
                with self.notification_history_lock:
                    items = list(self.notification_history)[-limit:]
                logger.debug(f"[notifications] history limit={limit} -> {len(items)}")
                return jsonify(items), 200
            except Exception as e:
                logger.error(f"获取通知历史失败: {e}")
                return jsonify({'message': '服务器内部错误'}), 500

        @self.app.route('/notifications/ack', methods=['POST'])
        def notifications_ack():
            """通知确认回执（应用内弹窗已展示/已处理）"""
            try:
                data = request.get_json() or {}
                notif_id = data.get('id')
                client_id = data.get('client_id')
                logger.debug(f"[notifications] ack id={notif_id} from_client={client_id}")
                ack = {
                    'type': 'ack',
                    'timestamp': datetime.now().isoformat(),
                    'payload': {
                        'id': notif_id,
                        'client_id': client_id,
                    },
                    'message': 'ack'
                }
                # ack 也进入推送通道，便于另一端看到“已送达/已查看”
                self.broadcast_notification(ack)
                return jsonify({'message': 'ok'}), 200
            except Exception as e:
                logger.error(f"通知确认失败: {e}")
                return jsonify({'message': '服务器内部错误'}), 500

        @self.app.route('/notifications/publish', methods=['POST'])
        def publish_notification():
            try:
                data = request.get_json() or {}
                # 避免刷屏：只记录关键信息，不打印完整 payload
                logger.debug(
                    "[notifications] publish type=%s from=%s to=%s require_delivery=%s",
                    data.get('type', 'info'),
                    data.get('from'),
                    data.get('to'),
                    bool(data.get('require_delivery', False)),
                )
                require_delivery = bool(data.get('require_delivery', False))
                notif = {
                    'type': data.get('type', 'info'),
                    'timestamp': datetime.now().isoformat(),
                    'payload': data.get('payload', {}),
                    'message': data.get('message', '有新的通知'),
                    'from': data.get('from'),
                    'to': data.get('to'),
                }
                self.broadcast_notification(notif)

                if require_delivery:
                    # 至少存在 1 个订阅者才算“可送达”（不保证对方已看见，但保证连接在线）
                    with self.notification_lock:
                        online = len(self.notification_subscribers)
                    return jsonify({'message': '已推送', 'delivered_possible': online > 0, 'online_subscribers': online, 'id': notif.get('id')}), 200

                return jsonify({'message': '已推送', 'id': notif.get('id')}), 200
            except Exception as e:
                logger.error(f"发送通知失败: {e}")
                return jsonify({'message': '服务器内部错误'}), 500

        # ========== 新增 日程管理 API ==========
        @self.app.route('/get_schedule', methods=['GET'])
        def get_schedule():
            try:
                data = self.load_assets_json('reminders.json')
                return jsonify(data.get('reminders', [])), 200
            except Exception as e:
                logger.error(f"获取日程失败: {e}")
                return jsonify({'message': '服务器内部错误'}), 500

        @self.app.route('/update_schedule', methods=['POST'])
        def update_schedule():
            try:
                payload = request.get_json()
                if not payload:
                    return jsonify({'message': '未接收到数据'}), 400

                schedules = self.load_assets_json('reminders.json').get('reminders', [])
                schedule_id = payload.get('schedule_id')
                if schedule_id is None:
                    schedule_id = (max((item.get('id', 0) for item in schedules), default=0) + 1)
                    schedules.append({
                        'id': schedule_id,
                        'time': payload.get('time', ''),
                        'event': payload.get('event', ''),
                        'completed': bool(payload.get('completed', False)),
                      })
                else:
                    updated = False
                    for item in schedules:
                        if item.get('id') == schedule_id:
                            item['time'] = payload.get('time', item['time'])
                            item['event'] = payload.get('event', item['event'])
                            item['completed'] = bool(payload.get('completed', item['completed']))
                            updated = True
                            break
                    if not updated:
                        return jsonify({'message': '未找到对应日程'}), 404

                if self.save_assets_json({'reminders': schedules}, 'reminders.json'):
                    return jsonify({'message': '日程保存成功', 'schedule_id': schedule_id}), 200
                return jsonify({'message': '保存失败'}), 500
            except Exception as e:
                logger.error(f"保存日程失败: {e}")
                return jsonify({'message': '服务器内部错误'}), 500

        @self.app.route('/delete_schedule', methods=['POST'])
        def delete_schedule():
            try:
                data = request.get_json()
                schedule_id = data.get('schedule_id')
                if schedule_id is None:
                    return jsonify({'message': '缺少 schedule_id'}), 400

                schedules = self.load_assets_json('reminders.json').get('reminders', [])
                schedules = [item for item in schedules if item.get('id') != schedule_id]
                if self.save_assets_json({'reminders': schedules}, 'reminders.json'):
                    return jsonify({'message': '删除成功'}), 200
                return jsonify({'message': '保存失败'}), 500
            except Exception as e:
                logger.error(f"删除日程失败: {e}")
                return jsonify({'message': '服务器内部错误'}), 500

        # 新增：重要消息广播 API
        @self.app.route('/broadcast_important_message', methods=['POST'])
        def broadcast_important_message():
            """
            接收一条重要提醒并保存，示例请求体:
            {
              "type": "face",  # 可选: face/medicine/other
              "message": "这是XXX，这是陌生人，下午5点要吃XX药了",
              "expires_at": "2025-10-01T17:30:00"
            }
            """
            try:
                data = request.get_json() or {}
                message = data.get('message', '').strip()
                if not message:
                    return jsonify({'message': '消息内容不能为空'}), 400

                msg_type = data.get('type', 'other')
                expires_at = data.get('expires_at')
                payload = {
                    'type': msg_type,
                    'message': message,
                    'created_at': datetime.now().isoformat(),
                    'expires_at': expires_at,
                }
                # 使用 uploads 目录下的 JSON 做持久化
                if self.save_json_data(payload, 'important_message.json'):
                    logger.info(f"[{datetime.now()}] 收到重要消息: {payload}")
                    return jsonify({'message': '重要消息已保存'}), 200
                return jsonify({'message': '保存失败'}), 500
            except Exception as e:
                logger.error(f"保存重要消息时出错: {e}")
                return jsonify({'message': '服务器内部错误'}), 500

        @self.app.route('/get_important_message', methods=['GET'])
        def get_important_message():
            """
            获取当前有效的重要提醒。
            若不存在或已过期，返回 { "has_message": false }。
            """
            try:
                data = self.load_json_data('important_message.json')
                if not data:
                    return jsonify({'has_message': False}), 200

                expires_at = data.get('expires_at')
                if expires_at:
                    try:
                        # 简单到期检查
                        exp = datetime.fromisoformat(expires_at)
                        if datetime.now() > exp:
                            return jsonify({'has_message': False}), 200
                    except Exception:
                        # expires_at 格式不对时忽略到期判断
                        pass

                return jsonify({
                    'has_message': True,
                    'type': data.get('type', 'other'),
                    'message': data.get('message', ''),
                    'created_at': data.get('created_at', ''),
                    'expires_at': data.get('expires_at', None),
                }), 200
            except Exception as e:
                logger.error(f"获取重要消息时出错: {e}")
                return jsonify({'message': '服务器内部错误'}), 500

        # ========== 患者活动监控 API ==========
        @self.app.route('/upload_activity', methods=['POST'])
        def upload_activity():
            """
            上传患者活动记录
            请求体:
            {
              "activity_type": "movement|rest|meal|medication",
              "description": "活动描述",
              "timestamp": "ISO8601时间戳"
            }
            """
            try:
                data = request.get_json()
                if not data:
                    return jsonify({'message': '未接收到有效数据'}), 400
                
                activity = {
                    'activity_type': data.get('activity_type', 'other'),
                    'description': data.get('description', ''),
                    'timestamp': data.get('timestamp') or datetime.now().isoformat(),
                }
                
                # 保存活动记录
                activities = self.load_json_data('activity_records.json') or []
                activities.append(activity)
                
                # 只保留最近200条记录
                if len(activities) > 200:
                    activities = activities[-200:]
                
                if self.save_json_data(activities, 'activity_records.json'):
                    logger.info(f"[{datetime.now()}] 患者活动已记录: {activity}")
                    return jsonify({'message': '活动记录已保存'}), 200
                return jsonify({'message': '保存失败'}), 500
            except Exception as e:
                logger.error(f"保存活动记录时出错: {e}")
                return jsonify({'message': '服务器内部错误'}), 500

        @self.app.route('/get_activity_stats', methods=['GET'])
        def get_activity_stats():
            """
            获取患者活动统计信息
            返回: 最近7天、24小时、1小时的活动数据及图表数据
            """
            try:
                from datetime import timedelta
                activities = self.load_json_data('activity_records.json') or []
                
                now = datetime.now()
                one_hour_ago = now - timedelta(hours=1)
                one_day_ago = now - timedelta(days=1)
                seven_days_ago = now - timedelta(days=7)
                
                # 统计不同时间段的活动
                one_hour_activities = []
                one_day_activities = []
                seven_day_activities = []
                
                for activity in activities:
                    try:
                        activity_time = datetime.fromisoformat(activity['timestamp'])
                        if activity_time > one_hour_ago:
                            one_hour_activities.append(activity)
                        if activity_time > one_day_ago:
                            one_day_activities.append(activity)
                        if activity_time > seven_days_ago:
                            seven_day_activities.append(activity)
                    except Exception:
                        pass
                
                # 统计各类型活动次数
                def count_by_type(activities_list):
                    counts = {}
                    for activity in activities_list:
                        atype = activity.get('activity_type', 'other')
                        counts[atype] = counts.get(atype, 0) + 1
                    return counts
                
                # 按小时统计最近24小时的活动
                hourly_counts = [0] * 24
                for activity in one_day_activities:
                    try:
                        activity_time = datetime.fromisoformat(activity['timestamp'])
                        hour = activity_time.hour
                        hourly_counts[hour] += 1
                    except Exception:
                        pass
                
                return jsonify({
                    'hour': {
                        'count': len(one_hour_activities),
                        'by_type': count_by_type(one_hour_activities)
                    },
                    'day': {
                        'count': len(one_day_activities),
                        'by_type': count_by_type(one_day_activities),
                        'hourly': hourly_counts  # 24小时数据，供图表使用
                    },
                    'week': {
                        'count': len(seven_day_activities),
                        'by_type': count_by_type(seven_day_activities)
                    },
                    'timestamp': datetime.now().isoformat()
                }), 200
            except Exception as e:
                logger.error(f"获取活动统计时出错: {e}")
                return jsonify({'message': '服务器内部错误'}), 500

        @self.app.route('/update_dog_location', methods=['POST'])
        def update_dog_location():
            """
            更新机器狗位置信息
            请求体:
            {
              "lat": 纬度,
              "lon": 经度,
              "location_name": "位置名称",
              "timestamp": "ISO8601时间戳"
            }
            """
            try:
                data = request.get_json()
                if not data or 'lat' not in data or 'lon' not in data:
                    return jsonify({'message': '缺少必要的GPS信息'}), 400
                
                location = {
                    'lat': data.get('lat'),
                    'lon': data.get('lon'),
                    'location_name': data.get('location_name', ''),
                    'timestamp': data.get('timestamp') or datetime.now().isoformat(),
                }
                
                # 保存最新位置
                if self.save_json_data(location, 'dog_location.json'):
                    logger.info(f"[{datetime.now()}] 机器狗位置已更新: {location}")
                    return jsonify({'message': '位置信息已保存'}), 200
                return jsonify({'message': '保存失败'}), 500
            except Exception as e:
                logger.error(f"保存位置信息时出错: {e}")
                return jsonify({'message': '服务器内部错误'}), 500

        @self.app.route('/get_dog_location', methods=['GET'])
        def get_dog_location():
            """
            获取机器狗当前位置
            """
            try:
                location = self.load_json_data('dog_location.json')
                if location:
                    return jsonify(location), 200
                return jsonify({
                    'lat': 0,
                    'lon': 0,
                    'location_name': '未知位置',
                    'timestamp': datetime.now().isoformat()
                }), 200
            except Exception as e:
                logger.error(f"获取位置信息时出错: {e}")
                return jsonify({'message': '服务器内部错误'}), 500

        @self.app.route('/update_companion_status', methods=['POST'])
        def update_companion_status():
            """
            更新机器狗陪伴状态
            请求体:
            {
              "is_accompanying": true/false,
              "timestamp": "ISO8601时间戳"
            }
            """
            try:
                data = request.get_json()
                if data is None:
                    return jsonify({'message': '未接收到有效数据'}), 400
                
                status = {
                    'is_accompanying': bool(data.get('is_accompanying', False)),
                    'timestamp': data.get('timestamp') or datetime.now().isoformat(),
                }
                
                # 保存当前陪伴状态
                if self.save_json_data(status, 'companion_status.json'):
                    logger.info(f"[{datetime.now()}] 陪伴状态已更新: {status}")
                    return jsonify({'message': '状态已保存'}), 200
                return jsonify({'message': '保存失败'}), 500
            except Exception as e:
                logger.error(f"保存陪伴状态时出错: {e}")
                return jsonify({'message': '服务器内部错误'}), 500

        @self.app.route('/get_companion_status', methods=['GET'])
        def get_companion_status():
            """
            获取机器狗陪伴状态
            """
            try:
                status = self.load_json_data('companion_status.json')
                if status:
                    # 检查最后一次更新是否超过5分钟，如果是则认为不陪伴
                    try:
                        last_update = datetime.fromisoformat(status['timestamp'])
                        if (datetime.now() - last_update).total_seconds() > 300:
                            status['is_accompanying'] = False
                    except Exception:
                        pass
                    return jsonify(status), 200
                return jsonify({
                    'is_accompanying': False,
                    'last_seen': None,
                    'timestamp': datetime.now().isoformat()
                }), 200
            except Exception as e:
                logger.error(f"获取陪伴状态时出错: {e}")
                return jsonify({'message': '服务器内部错误'}), 500

        # ========== 社区论坛 API ==========
        @self.app.route('/community/get_posts', methods=['GET'])
        def get_community_posts():
            try:
                data = self.load_assets_json('community.json')
                return jsonify(data.get('posts', [])), 200
            except Exception as e:
                logger.error(f"获取社区帖子失败: {e}")
                return jsonify({'message': '服务器内部错误'}), 500

        @self.app.route('/community/create_post', methods=['POST'])
        def create_community_post():
            try:
                payload = request.get_json() or {}
                posts = self.load_assets_json('community.json').get('posts', [])
                post_id = (max((p.get('id', 0) for p in posts), default=0) + 1)
                post = {
                    'id': post_id,
                    'title': payload.get('title', '').strip(),
                    'content': payload.get('content', '').strip(),
                    'author': payload.get('author', '匿名'),
                    'timestamp': datetime.now().isoformat(),
                    'likes': 0,
                    'comments': [],
                }
                posts.insert(0, post)
                if self.save_assets_json({'posts': posts}, 'community.json'):
                    return jsonify({'message': '发帖成功', 'post_id': post_id}), 200
                return jsonify({'message': '保存失败'}), 500
            except Exception as e:
                logger.error(f"创建帖子失败: {e}")
                return jsonify({'message': '服务器内部错误'}), 500

        @self.app.route('/community/comment_post', methods=['POST'])
        def comment_community_post():
            try:
                payload = request.get_json() or {}
                post_id = payload.get('post_id')
                text = payload.get('text', '').strip()
                author = payload.get('author', '匿名')
                if post_id is None or text == '':
                    return jsonify({'message': '参数缺失'}), 400

                data = self.load_assets_json('community.json')
                posts = data.get('posts', [])
                for p in posts:
                    if p.get('id') == post_id:
                        comment = {
                            'id': (max((c.get('id', 0) for c in p.get('comments', [])), default=0) + 1),
                            'author': author,
                            'text': text,
                            'timestamp': datetime.now().isoformat(),
                        }
                        p.setdefault('comments', []).append(comment)
                        if self.save_assets_json({'posts': posts}, 'community.json'):
                            return jsonify({'message': '评论成功'}), 200
                        return jsonify({'message': '保存失败'}), 500

                return jsonify({'message': '未找到帖子'}), 404
            except Exception as e:
                logger.error(f"评论失败: {e}")
                return jsonify({'message': '服务器内部错误'}), 500

        @self.app.route('/community/like_post', methods=['POST'])
        def like_community_post():
            try:
                payload = request.get_json() or {}
                post_id = payload.get('post_id')
                if post_id is None:
                    return jsonify({'message': '参数缺失'}), 400
                data = self.load_assets_json('community.json')
                posts = data.get('posts', [])
                for p in posts:
                    if p.get('id') == post_id:
                        p['likes'] = int(p.get('likes', 0)) + 1
                        if self.save_assets_json({'posts': posts}, 'community.json'):
                            return jsonify({'message': '已点赞', 'likes': p['likes']}), 200
                        return jsonify({'message': '保存失败'}), 500
                return jsonify({'message': '未找到帖子'}), 404
            except Exception as e:
                logger.error(f"点赞失败: {e}")
                return jsonify({'message': '服务器内部错误'}), 500

        # ========== 视频直播 API ==========
        @self.app.route('/get_available_videos', methods=['GET'])
        def get_available_videos():
            """
            获取可用的视频文件列表
            """
            try:
                videos = []
                if os.path.exists(self.video_folder):
                    for filename in os.listdir(self.video_folder):
                        filepath = os.path.join(self.video_folder, filename)
                        if os.path.isfile(filepath):
                            videos.append({
                                'filename': filename,
                                'size': os.path.getsize(filepath),
                                'available': True
                            })
                
                return jsonify({
                    'videos': videos,
                    'count': len(videos)
                }), 200
            except Exception as e:
                logger.error(f"获取视频列表失败: {e}")
                return jsonify({'message': '服务器内部错误'}), 500

        @self.app.route('/start_video_stream', methods=['POST'])
        def start_video_stream_route():
            """
            启动视频直播
            请求体:
            {
              "video_filename": "example.mp4"
            }
            """
            try:
                data = request.get_json()
                if not data or 'video_filename' not in data:
                    return jsonify({'message': '缺少video_filename参数'}), 400
                
                video_filename = data.get('video_filename')
                if self.start_video_stream(video_filename):
                    return jsonify({'message': '视频直播已启动', 'video': video_filename}), 200
                else:
                    return jsonify({'message': '启动视频直播失败'}), 400
            except Exception as e:
                logger.error(f"启动视频直播路由错误: {e}")
                return jsonify({'message': '服务器内部错误'}), 500

        @self.app.route('/stop_video_stream', methods=['POST'])
        def stop_video_stream_route():
            """
            停止视频直播
            """
            try:
                if self.stop_video_stream():
                    return jsonify({'message': '视频直播已停止'}), 200
                else:
                    return jsonify({'message': '停止视频直播失败'}), 400
            except Exception as e:
                logger.error(f"停止视频直播路由错误: {e}")
                return jsonify({'message': '服务器内部错误'}), 500

        @self.app.route('/video_feed')
        def video_feed():
            """
            获取视频直播流（MJPEG格式）
            """
            try:
                if not self.is_streaming or not self.video_stream_path:
                    return jsonify({'message': '视频直播未启动'}), 400
                
                if not os.path.exists(self.video_stream_path):
                    logger.error(f"视频文件不存在: {self.video_stream_path}")
                    return jsonify({'message': '视频文件不存在'}), 404
                
                return Response(
                    self.get_video_stream_generator(self.video_stream_path),
                    mimetype='multipart/x-mixed-replace; boundary=frame'
                )
            except Exception as e:
                logger.error(f"视频流端点错误: {e}")
                return jsonify({'message': '服务器内部错误'}), 500

        @self.app.route('/get_stream_status', methods=['GET'])
        def get_stream_status():
            """
            获取视频直播状态
            """
            try:
                return jsonify({
                    'is_streaming': self.is_streaming,
                    'video_file': getattr(self, 'video_stream_path', None),
                    'timestamp': datetime.now().isoformat()
                }), 200
            except Exception as e:
                logger.error(f"获取直播状态失败: {e}")
                return jsonify({'message': '服务器内部错误'}), 500

        # 错误处理
        @self.app.errorhandler(413)
        def too_large(e):
            """处理文件过大错误"""
            return jsonify({'message': '文件大小超过限制(16MB)'}), 413

        @self.app.errorhandler(500)
        def internal_error(e):
            """处理内部服务器错误"""
            return jsonify({'message': '服务器内部错误'}), 500
        
        



    
    def run_server(self, port=5000):
        """运行Flask服务器"""
        print("启动机器狗控制服务器...")
        print(f"上传目录: {os.path.abspath(self.app.config['UPLOAD_FOLDER'])}")
        print(f"服务器地址: http://0.0.0.0:{port}")
        
        # 使用多线程模式运行
        self.app.run(host='0.0.0.0', port=port, debug=False, threaded=True)
    
    def start(self, port=5000):
        """启动服务器线程"""
        server_thread = threading.Thread(target=self.run_server, kwargs={'port': port})
        server_thread.daemon = True
        server_thread.start()
        print(f"机器狗API服务器已启动在端口{port}")

# 集成到现有的机器狗主程序
def main():
    # 创建机器狗服务器实例
    dog_server = DogServer()
    dog_server.start()
    
    # 原有的机器狗主循环
    try:
        while True:
            # 这里可以添加机器狗的主要逻辑
            # 例如：处理视觉识别、运动控制等
            time.sleep(1)
    except KeyboardInterrupt:
        print("程序退出")

if __name__ == '__main__':
    main()