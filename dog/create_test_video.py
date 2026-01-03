"""
创建一个简单的测试视频用于模拟机器狗摄像头直播

使用说明：
1. 运行此脚本: python create_test_video.py
2. 将会在 dog/assets/videos/ 目录创建 test_video.mp4
3. 视频内容为简单的动画和文字，用于测试直播功能
"""

import cv2
import numpy as np
import os

def create_test_video():
    # 视频参数
    width, height = 640, 480
    fps = 30
    duration = 10  # 秒
    
    # 输出路径
    script_dir = os.path.dirname(os.path.abspath(__file__))
    output_path = os.path.join(script_dir, 'assets', 'videos', 'test_video.mp4')
    
    # 确保目录存在
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    
    # 创建视频写入器
    fourcc = cv2.VideoWriter_fourcc(*'mp4v')
    out = cv2.VideoWriter(output_path, fourcc, fps, (width, height))
    
    if not out.isOpened():
        print("错误：无法创建视频文件")
        return
    
    total_frames = fps * duration
    
    print(f"正在创建测试视频... ({duration}秒, {fps}FPS)")
    
    for frame_num in range(total_frames):
        # 创建黑色背景
        frame = np.zeros((height, width, 3), dtype=np.uint8)
        
        # 添加渐变背景色
        color_value = int((frame_num / total_frames) * 255)
        frame[:, :] = (color_value // 3, color_value // 2, color_value)
        
        # 添加移动的圆形（模拟机器狗视角中的物体）
        circle_x = int((frame_num / total_frames) * width)
        circle_y = height // 2
        cv2.circle(frame, (circle_x, circle_y), 50, (0, 255, 0), -1)
        
        # 添加文字
        text = f"机器狗摄像头测试 - 帧: {frame_num}/{total_frames}"
        cv2.putText(frame, text, (20, 50), 
                   cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)
        
        # 添加时间戳
        time_text = f"时间: {frame_num/fps:.2f}s"
        cv2.putText(frame, time_text, (20, 100), 
                   cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 255), 2)
        
        # 添加模拟的传感器数据
        sensor_text = f"温度: {20 + (frame_num % 10)}°C  湿度: {45 + (frame_num % 15)}%"
        cv2.putText(frame, sensor_text, (20, height - 50), 
                   cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 255), 1)
        
        # 添加边框
        cv2.rectangle(frame, (10, 10), (width-10, height-10), (255, 255, 255), 2)
        
        out.write(frame)
        
        # 进度显示
        if frame_num % fps == 0:
            progress = (frame_num / total_frames) * 100
            print(f"进度: {progress:.0f}%")
    
    out.release()
    print(f"✓ 测试视频创建成功: {output_path}")
    print(f"  - 分辨率: {width}x{height}")
    print(f"  - 帧率: {fps} FPS")
    print(f"  - 时长: {duration} 秒")
    print("\n现在可以在 Flutter 应用中启动视频直播了！")

if __name__ == '__main__':
    try:
        import cv2
        create_test_video()
    except ImportError:
        print("错误：需要安装 opencv-python")
        print("请运行: pip install opencv-python")
    except Exception as e:
        print(f"错误：{e}")
