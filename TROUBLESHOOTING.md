# 视频直播功能故障排查指南

## 快速修复步骤

### 1. 安装后端依赖
```bash
cd c:\Users\97266\Desktop\DogApp2\dog
install_dependencies.bat
```

或手动安装：
```bash
conda activate py39_kivy
pip install flask flask-cors opencv-python
```

### 2. 检查视频文件
确保 `dog/assets/videos/` 文件夹中有视频文件：
- test_video.mp4
- video.mp4

### 3. 启动后端服务
```bash
cd c:\Users\97266\Desktop\DogApp2\dog
start_server.bat
```

### 4. 测试后端 API

#### 4.1 获取可用视频列表
在浏览器中访问：
```
http://localhost:5000/get_available_videos
```

应该返回：
```json
{
  "videos": ["test_video.mp4", "video.mp4"]
}
```

#### 4.2 启动视频直播
使用 PowerShell 或 curl：
```powershell
Invoke-RestMethod -Uri "http://localhost:5000/start_video_stream" -Method POST -ContentType "application/json" -Body '{"video_filename":"test_video.mp4"}'
```

应该返回：
```json
{
  "message": "视频直播已启动",
  "video": "test_video.mp4"
}
```

#### 4.3 测试视频流
在浏览器中访问：
```
http://localhost:5000/video_feed
```

应该能看到视频播放（MJPEG 流）。

#### 4.4 检查直播状态
```
http://localhost:5000/get_stream_status
```

应该返回：
```json
{
  "is_streaming": true,
  "video_path": "test_video.mp4"
}
```

### 5. 启动 Flutter 应用
```bash
cd c:\Users\97266\Desktop\DogApp2
flutter run
```

### 6. 使用直播功能
1. 在应用中切换到"监控"标签
2. 点击"视频"子标签
3. 从下拉列表选择视频文件（如 test_video.mp4）
4. 点击"启动直播"按钮
5. 视频流应该会显示在上方的播放区域

## 常见问题

### 问题 1: "无法连接到视频流"

**原因**：
- 后端服务未运行
- 视频直播未启动
- OpenCV 未安装
- 网络连接问题

**解决方法**：
1. 检查后端服务是否运行：
   ```bash
   # 检查进程
   tasklist | findstr python
   ```

2. 查看后端日志：
   ```
   dog/dog.log
   ```

3. 确认 OpenCV 已安装：
   ```bash
   conda activate py39_kivy
   python -c "import cv2; print(cv2.__version__)"
   ```

4. 手动测试视频流（用浏览器访问）：
   ```
   http://localhost:5000/video_feed
   ```

### 问题 2: 后端返回 "视频直播未启动"

**原因**：
- 忘记调用启动接口
- 启动接口返回失败

**解决方法**：
1. 先调用启动接口：
   ```bash
   curl -X POST http://localhost:5000/start_video_stream -H "Content-Type: application/json" -d "{\"video_filename\":\"test_video.mp4\"}"
   ```

2. 检查返回结果是否成功

3. 在 Flutter 应用中确保点击了"启动直播"按钮

### 问题 3: 视频文件不存在

**原因**：
- videos 文件夹中没有视频文件

**解决方法**：
1. 运行测试视频生成脚本：
   ```bash
   cd c:\Users\97266\Desktop\DogApp2\dog
   python create_test_video.py
   ```

2. 或手动将视频文件复制到：
   ```
   dog/assets/videos/
   ```

### 问题 4: OpenCV 无法打开视频

**原因**：
- 视频文件损坏
- 视频格式不支持
- OpenCV 版本问题

**解决方法**：
1. 检查视频文件是否完整：
   ```bash
   python -c "import cv2; cap = cv2.VideoCapture('dog/assets/videos/test_video.mp4'); print('Can open:', cap.isOpened())"
   ```

2. 尝试使用其他视频文件（MP4、AVI、MOV 格式）

3. 重新生成测试视频：
   ```bash
   python create_test_video.py
   ```

### 问题 5: CORS 错误

**原因**：
- flask-cors 未安装
- CORS 配置问题

**解决方法**：
1. 确保 flask-cors 已安装：
   ```bash
   pip install flask-cors
   ```

2. 检查 dog_server.py 中是否有：
   ```python
   from flask_cors import CORS
   CORS(app)
   ```

## 调试技巧

### 1. 查看后端日志
```bash
type dog\dog.log
```

### 2. 启用详细日志
在 `dog_server.py` 中将日志级别改为 DEBUG：
```python
logging.basicConfig(level=logging.DEBUG, ...)
```

### 3. 测试网络连接
```powershell
Test-NetConnection -ComputerName localhost -Port 5000
```

### 4. 检查 Flutter 端 API 调用
在 `lib/services/api.dart` 中添加打印语句：
```dart
print('Calling: $url');
print('Response: ${response.body}');
```

## 架构说明

### 后端视频流处理流程：
1. 客户端调用 `/start_video_stream` 启动直播
2. 服务器设置 `is_streaming = True` 和 `video_stream_path`
3. 客户端通过 `/video_feed` 获取 MJPEG 流
4. `get_video_stream_generator` 循环读取视频帧
5. 每帧编码为 JPEG 并通过 HTTP multipart 发送

### Flutter 端显示流程：
1. 使用 `Image.network` 显示 MJPEG 流
2. URL: `http://localhost:5000/video_feed`
3. 自动处理 multipart/x-mixed-replace 格式
4. 显示加载/错误状态

## 性能优化

### 1. 调整帧率
在 `get_video_stream_generator` 中修改：
```python
time.sleep(0.033)  # 30 FPS
time.sleep(0.066)  # 15 FPS (降低 CPU 占用)
```

### 2. 调整图像质量
```python
ret, buffer = cv2.imencode('.jpg', frame, [cv2.IMWRITE_JPEG_QUALITY, 80])
```

### 3. 调整视频分辨率
```python
frame = cv2.resize(frame, (640, 480))
```

## 联系支持

如果以上方法都无法解决问题，请提供：
1. 后端日志文件（dog/dog.log）
2. 错误截图
3. 浏览器 F12 控制台错误信息
4. Python 和 OpenCV 版本信息
