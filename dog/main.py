import sys
import signal
import asyncio
import logging

# 将 dog 目录加入路径，便于导入
import os
import time
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
if BASE_DIR not in sys.path:
    sys.path.insert(0, BASE_DIR)

from dog_server import DogServer
from webrtc_server import WebRTCServer

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class AppLauncher:
    def __init__(self):
        self.dog_server = DogServer()
        self.webrtc_server = WebRTCServer()
        self.api_port = 8080

    def start(self):
        def start_dog():
            self.dog_server.start(port=self.api_port)

        # 启动 webrtc_server（内部已管理 asyncio 线程循环）
        def start_webrtc():
            webrtc_port = self.api_port + 1
            logger.info(f"启动 webrtc_server on 0.0.0.0:{webrtc_port}")
            self.webrtc_server.run(host='0.0.0.0', port=webrtc_port, debug=False)

        start_dog()
        import threading
        t2 = threading.Thread(target=start_webrtc, daemon=True)
        t2.start()

        # 信号处理与阻塞主线程
        logger.info("两个后端已启动，按 Ctrl+C 退出")
        while True:
            time.sleep(1)



def main():
    app = AppLauncher()
    app.start()

if __name__ == '__main__':
    main()
