# WebRTC 视频直播配置指南

## 概述

本系统使用 WebRTC 技术实现低延迟的视频直播功能，相比传统的 MJPEG 方案具有以下优势：
- 更低的延迟（通常 < 500ms）
- 更高的视频质量
- 更好的网络适应性
- 支持点对点连接

## 架构

### 后端（Python）
- **aiortc**: WebRTC 实现
- **Flask-SocketIO**: 信令服务器
- **OpenCV**: 视频帧处理

### 前端（Flutter）
- **flutter_webrtc**: WebRTC 客户端
- **socket_io_client**: Socket.IO 客户端

## 安装依赖

### 1. 安装 Python 依赖

```bash
cd dog
conda activate py39_kivy
pip install flask flask-cors opencv-python aiortc python-socketio flask-socketio
```

或使用安装脚本：
```bash
cd dog
install_webrtc_dependencies.bat
```

### 2. 安装 Flutter 依赖

```bash
cd ..
flutter pub get
```

## 启动服务

### 1. 启动 WebRTC 服务器

```bash
cd dog
python webrtc_server.py
```

服务器将在 `http://localhost:5001` 启动。

或使用启动脚本：
```bash
cd dog
start_webrtc_server.bat
```

### 2. 启动 Flutter 应用

```bash
flutter run
```

## 使用说明

### 在应用中使用视频直播

1. 打开应用，进入"监控"标签
2. 切换到"视频"子标签
3. 从下拉列表中选择视频文件
4. 点击"启动直播"按钮
5. 等待连接建立（通常需要 2-3 秒）
6. 视频流将显示在播放区域
7. 点击"停止直播"按钮可以停止播放

## API 端点

### Socket.IO 事件

#### 客户端发送的事件

| 事件名 | 数据 | 说明 |
|--------|------|------|
| `start_stream` | `{video_filename: string}` | 启动视频流 |
| `stop_stream` | `{}` | 停止视频流 |
| `get_videos` | `{}` | 获取视频列表 |
| `offer` | `{sdp: string, type: string}` | WebRTC offer |
| `ice_candidate` | `{candidate: object}` | ICE candidate |

#### 服务器发送的事件

| 事件名 | 数据 | 说明 |
|--------|------|------|
| `connected` | `{session_id: string}` | 连接确认 |
| `stream_started` | `{video_filename: string}` | 视频流已启动 |
| `stream_stopped` | `{}` | 视频流已停止 |
| `videos_list` | `{videos: string[]}` | 视频列表 |
| `answer` | `{sdp: string, type: string}` | WebRTC answer |
| `error` | `{message: string}` | 错误信息 |

## 连接流程

### WebRTC 握手过程

1. **客户端初始化**
   ```
   客户端 -> Socket.IO 连接 -> 服务器
   服务器 -> connected 事件 -> 客户端
   ```

2. **选择视频**
   ```
   客户端 -> start_stream {video_filename} -> 服务器
   服务器 -> stream_started -> 客户端
   ```

3. **WebRTC 握手**
   ```
   客户端 -> 创建 PeerConnection
   客户端 -> 创建 Offer -> 发送 offer 事件 -> 服务器
   服务器 -> 创建 Answer -> 发送 answer 事件 -> 客户端
   客户端 -> 设置远程描述
   ```

4. **ICE 协商**
   ```
   客户端/服务器 -> 交换 ICE candidates
   建立 P2P 连接
   ```

5. **视频流传输**
   ```
   服务器 -> 读取视频帧 -> 编码 -> 发送到客户端
   客户端 -> 接收帧 -> 解码 -> 渲染
   ```

## 故障排查

### 问题 1: 无法连接到 WebRTC 服务器

**症状**: "初始化失败" 或 "无法连接"

**解决方法**:
1. 确认 WebRTC 服务器已启动：
   ```bash
   # 检查端口
   netstat -ano | findstr 5001
   ```

2. 检查防火墙设置，确保端口 5001 开放

3. 查看服务器日志：
   ```bash
   # 在服务器终端查看实时日志
   ```

### 问题 2: 视频流连接失败

**症状**: "正在连接视频流..." 一直显示

**解决方法**:
1. 确认已选择视频文件
2. 确认视频文件存在于 `dog/assets/videos/` 目录
3. 检查 OpenCV 是否能打开视频：
   ```bash
   python -c "import cv2; cap = cv2.VideoCapture('dog/assets/videos/test_video.mp4'); print('Can open:', cap.isOpened())"
   ```

### 问题 3: ICE 连接失败

**症状**: 日志显示 "ICE 连接状态: failed"

**解决方法**:
1. 检查网络连接
2. 确认 STUN 服务器可访问：`stun:stun.l.google.com:19302`
3. 如果在受限网络环境，可能需要配置 TURN 服务器

### 问题 4: 视频播放卡顿

**症状**: 视频不流畅，有明显延迟

**解决方法**:
1. 降低视频分辨率（在 `webrtc_server.py` 中调整）
2. 调整视频帧率
3. 检查 CPU 使用率
4. 优化视频编码参数

### 问题 5: aiortc 安装失败

**症状**: `pip install aiortc` 报错

**解决方法**:
1. 确保有 C++ 编译器（Windows 需要 Visual Studio Build Tools）
2. 尝试使用预编译的 wheel:
   ```bash
   pip install --only-binary :all: aiortc
   ```
3. 或使用 conda:
   ```bash
   conda install -c conda-forge aiortc
   ```

## 配置优化

### 调整视频质量

编辑 `dog/webrtc_server.py`，在 `VideoStreamTrack.recv` 方法中添加：

```python
# 调整分辨率
frame = cv2.resize(frame, (1280, 720))  # 720p
frame = cv2.resize(frame, (640, 480))   # 480p

# 调整压缩质量
ret, buffer = cv2.imencode('.jpg', frame, [cv2.IMWRITE_JPEG_QUALITY, 85])
```

### 调整帧率

在 `VideoStreamTrack` 中修改时间戳增量：

```python
# 30 FPS
self.pts += 1/30.0

# 15 FPS
self.pts += 1/15.0
```

### 配置 ICE 服务器

编辑 `lib/services/webrtc_service.dart`，修改 ICE 服务器配置：

```dart
final configuration = {
  'iceServers': [
    {'urls': 'stun:stun.l.google.com:19302'},
    {'urls': 'stun:stun1.l.google.com:19302'},
    // 添加 TURN 服务器（如需要）
    {
      'urls': 'turn:your-turn-server.com:3478',
      'username': 'user',
      'credential': 'pass'
    },
  ]
};
```

## 性能指标

### 推荐配置

| 场景 | 分辨率 | 帧率 | 码率 | 延迟 |
|------|--------|------|------|------|
| 高质量 | 1920x1080 | 30 FPS | ~5 Mbps | 200-500ms |
| 标准 | 1280x720 | 30 FPS | ~2 Mbps | 150-400ms |
| 低带宽 | 640x480 | 15 FPS | ~500 Kbps | 100-300ms |

### CPU 使用

- Python 服务器: 10-30% (单核)
- Flutter 客户端: 5-15% (单核)

## 安全建议

1. **使用 HTTPS/WSS**: 生产环境必须使用加密连接
2. **身份验证**: 添加 Socket.IO 认证机制
3. **权限控制**: 限制视频文件访问权限
4. **速率限制**: 防止 DoS 攻击

示例认证配置：

```python
@socketio.on('connect')
def handle_connect(auth):
    token = auth.get('token')
    if not verify_token(token):
        return False  # 拒绝连接
```

## 高级功能

### 添加音频支持

1. 修改 `VideoStreamTrack` 为 `MediaStreamTrack`
2. 添加音频轨道
3. 配置音频编解码器

### 录制功能

使用 `aiortc.contrib.media.MediaRecorder` 录制流：

```python
recorder = MediaRecorder('output.mp4')
recorder.addTrack(video_track)
await recorder.start()
```

### 多客户端支持

当前实现支持多个客户端同时连接，每个客户端有独立的视频流。

## 参考资料

- [aiortc 文档](https://aiortc.readthedocs.io/)
- [flutter_webrtc 文档](https://github.com/flutter-webrtc/flutter-webrtc)
- [WebRTC 规范](https://www.w3.org/TR/webrtc/)
- [Socket.IO 文档](https://socket.io/docs/v4/)

## 更新日志

### 2026-01-03
- 将视频直播从 MJPEG 迁移到 WebRTC
- 实现基于 aiortc 的服务器端
- 实现基于 flutter_webrtc 的客户端
- 添加 Socket.IO 信令服务器
- 支持视频文件循环播放
