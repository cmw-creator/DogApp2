# DogApp2 📱

Flutter/WebRTC Remote Control App for Companion Robot Dog

> **机器狗远程控制App** | 实时视频流 + 语音对讲 + 遥控指令

## 🎯 概述

DogApp2是为"AD陪伴机器狗"项目配套的移动端远程控制应用，基于Flutter框架开发，通过WebRTC实现低延迟实时图传和语音对讲。

## ✨ 功能

- 🎥 **实时视频流** — WebRTC P2P连接，延迟<200ms
- 🎤 **语音对讲** — 双向语音，支持远程喊话
- 🎮 **遥控指令** — 方向控制 + 速度调节
- 🗺️ **状态显示** — 电池、位置、连接状态
- 🔐 **多设备** — 支持多个手机同时连接

## 🛠️ 技术栈

| 技术 | 用途 |
|------|------|
| **Flutter** | 跨平台UI框架 |
| **WebRTC** | 实时音视频传输 |
| **Dart** | 开发语言 |
| **WebSocket** | 信令服务 |

## 🚀 快速开始

```bash
flutter pub get
flutter run
```

## 📂 项目结构

```
lib/
├── main.dart           # 入口
├── pages/              # 页面
│   ├── home_page.dart
│   ├── control_page.dart
│   └── settings_page.dart
├── services/           # 服务
│   ├── webrtc_service.dart
│   └── websocket_service.dart
├── models/             # 数据模型
└── widgets/            # 组件
```

## 🔗 关联项目

- [RememberDog](https://github.com/cmw-creator/RememberDog) — 陪伴机器狗核心系统

## 📧 联系
王承孟 | wcm@njust.edu.cn | [GitHub](https://github.com/cmw-creator)

