import json
import time
import urllib.request

BASE = "http://127.0.0.1:5000"


def post(path: str, payload: dict):
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        BASE + path,
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=5) as resp:
        return resp.status, resp.read().decode("utf-8")


if __name__ == "__main__":
    print("Sending test notification...")
    status, body = post(
        "/notifications/publish",
        {
            "type": "test",
            "message": f"联调测试通知 {time.strftime('%H:%M:%S')}",
            "from": "tools/notify_test",\
            "to": "all",
            "payload": {"hello": "world"},
        },
    )
    print(status, body)

    print("Sending SOS...")
    status, body = post(
        "/sos_alert",
        {"message": f"SOS 联调测试 {time.strftime('%H:%M:%S')}"},
    )
    print(status, body)
