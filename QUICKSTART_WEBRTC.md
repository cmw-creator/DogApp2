# WebRTC 直播快速开始

## 已完成的更改

✅ 将视频直播从 MJPEG 升级到 WebRTC
✅ 后端使用 aiortc + Flask-SocketIO
✅ 前端使用 flutter_webrtc + socket_io_client
✅ 支持低延迟视频流传输
✅ 自动视频循环播放

## 快速启动

### 1. 安装后端依赖
```bash
cd dog
install_webrtc_dependencies.bat
```

### 2. 启动 WebRTC 服务器
```bash
cd dog
start_webrtc_server.bat
```
服务器将在 http://localhost:5001 运行

### 3. 启动 Flutter 应用
```bash
flutter run
```

### 4. 使用直播
1. 进入"监控" → "视频"标签
2. 选择视频文件（test_video.mp4 或 video.mp4）
3. 点击"启动直播"
4. 等待 2-3 秒建立 WebRTC 连接
5. 观看低延迟视频直播

## 主要改进

### 性能提升
- **延迟**: 从 MJPEG 的 1-2 秒降低到 WebRTC 的 200-500 毫秒
- **质量**: 更好的视频编码和自适应码率
- **稳定性**: 自动处理网络抖动和丢包

### 架构优势
- **点对点连接**: 支持 P2P 传输（通过 ICE/STUN）
- **可扩展性**: 可轻松添加音频、录制等功能
- **标准化**: 基于 W3C WebRTC 标准

## 新增文件

### 后端
- `dog/webrtc_server.py` - WebRTC 信令服务器和视频流处理
- `dog/start_webrtc_server.bat` - 启动脚本
- `dog/install_webrtc_dependencies.bat` - 依赖安装脚本

### 前端
- `lib/services/webrtc_service.dart` - WebRTC 客户端服务

### 文档
- `WEBRTC_GUIDE.md` - 完整配置和故障排查指南
- `QUICKSTART_WEBRTC.md` - 本文件

## 依赖变更

### Python (dog/pyproject.toml)
```toml
dependencies = [
    "flask>=3.1.2",
    "flask-cors>=4.0.0",
    "opencv-python>=4.8.0",
    "aiortc>=1.6.0",                # 新增
    "python-socketio>=5.10.0",      # 新增
    "flask-socketio>=5.3.5",        # 新增
]
```

### Flutter (pubspec.yaml)
```yaml
dependencies:
  flutter_webrtc: ^0.9.48    # 新增
  socket_io_client: ^2.0.3   # 新增
```

## 端口变更

- **原 MJPEG 服务器**: http://localhost:5000 (仍保留用于其他 API)
- **新 WebRTC 服务器**: http://localhost:5001 (WebRTC 专用)

## 常见问题

### Q: aiortc 安装失败？
A: 需要 C++ 编译器。Windows 用户安装 Visual Studio Build Tools 或尝试：
```bash
conda install -c conda-forge aiortc
```

### Q: 视频流连接失败？
A: 
1. 确认 WebRTC 服务器在端口 5001 运行
2. 确认视频文件存在于 `dog/assets/videos/`
3. 查看控制台错误信息

### Q: 如何调整视频质量？
A: 编辑 `dog/webrtc_server.py` 中的 `VideoStreamTrack` 类，调整分辨率和帧率

## 技术细节

### WebRTC 连接流程
1. Socket.IO 建立信令通道
2. 客户端发送 start_stream 请求
3. 客户端创建 offer，服务器响应 answer
4. ICE 协商建立最优连接路径
5. 开始视频流传输

### 视频处理管道
```
视频文件 → OpenCV 读取 → 编码为 VideoFrame → WebRTC 传输 → 客户端解码 → RTCVideoView 显示
```

## 下一步

可以进一步优化：
- 添加音频支持
- 实现视频录制
- 添加多路视频切换
- 优化移动网络适配

详细信息请参考 `WEBRTC_GUIDE.md`
