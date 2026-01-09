# 开发环境配置

* 安装前注意：很多包国内环境不好下载，可能开全局梯子或者要配置一些镜像
* 服务器默认20.89.159.15:8080(web rtc 8081)，1月里一直开着

## 1 Flutter手动安装：

- 参考：[手动安装 | Flutter 框架](https://docs.fluttercn.cn/install/manual)

1. 下载flutter sdk [flutter_windows](https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.38.3-stable.zip)

2. 解压至文件夹，保证路径中**不包含特殊字符或空格**且不需要提升权限。

3. 将bin文件夹加入系统PATH环境

4. 安装成功验证，cmd.exe运行：

```cmd.exe
flutter --version
dart --version
```

5. 可查看有哪些运行环境，先不必要解决缺失的
 ```
 flutter doctor
 ```

   
## 2 java环境(可选)

- 在edge浏览器里打开不需要，打包成apk需要

### 安装jdk 17

[Java Archive Downloads - Java SE 17.0.12 and earlier](https://www.oracle.com/java/technologies/javase/jdk17-archive-downloads.html)

### 验证，cmd.exe运行：

```
java --version
```

## 3 IDE配置，以下两种选一个

## 3.1 VS code

### 对于VS code，安装插件

**Flutter**：安装此插件时会**自动安装 Dart 插件**

~~此外，你还可以考虑安装一些提升效率的辅助插件，如 `Awesome Flutter Snippets`（代码片段）和 `Error Lens`（增强错误提示）。~~


### 插件验证

在 VS Code 中，通过快捷键 `Ctrl+Shift+P`(Windows/Linux) 或 `Cmd+Shift+P`(macOS) 打开命令面板，输入并执行 `Flutter: Run Flutter Doctor`命令 。这会在输出窗口显示一份详细的环境健康报告，它会明确指出缺失的依赖或未同意的协议。
### 运行

打开项目文件夹，在左侧选择“运行和调试”，点击Dart & Flutter，选择Flutter Edge，利用浏览器打开

![一张图展示了如何在VS Code中配置Flutter开发环境](doc\pic\1.png)

### 新建项目
`Ctrl+Shift+P` + `Flutter: New Project`


## 3.2 使用Android Studio和安卓模拟器

1. 访问 Android Studio 官网下载安装程序，并完成安装。

2. 首次打开后进行配置，可以全默认。(选custom就下载全勾上)

3. 安装开发插件:Flutter 和 Dart

4. **安装系统镜像**：在 **SDK Manager**中，切换到 **SDK Platforms**选项卡，选择你需要的 Android 版本（例如 Android 14）进行安装。应该自带一个Android 16的环境，推荐使用api29(Android 10)的环境。

5. 设置sdk环境 flutter config --android-sdk [your path]，可能在第1步自动安装

6. 打开项目文件夹

7. 启动安卓模拟器，选择该设备，运行。

 Android Studio同样支持edge浏览器模式，选择edge运行即可

## 4 运行项目
解决依赖,在项目根目录运行：

```
flutter pub get
flutter run
```
### 4.1 启动后端(非必须)
运行dog/dog_server.py，怎么运行都行。
### 4.2 启动前端
直接参考IDE启动即可

## 5 打包成本地apk

```
flutter build apk --release
```
## 6 常见问题
 
# 项目介绍
### 简介

`DogApp2` 是一个基于 Flutter 的移动/跨平台客户端，与轻量级 Python 服务端配合的宠物管理与远程视频交互应用。项目集成了本地媒体管理、提醒、家庭/成员管理以及基于 WebRTC 的实时视频通话功能（客户端使用 Flutter，后端使用 Python 提供测试/开发服务）。

### 关键功能
- 多端运行：支持 Android、iOS、Web（通过 Flutter）
- 本地媒体管理：照片、视频、活动记录等
- 家庭和陪伴者管理：家庭成员、陪伴者状态同步
- 提醒和日程：本地提醒记录与管理
- 实时视频/音频：使用 WebRTC 建立点对点或通过信令服务器协商的连接

### 架构与技术栈
- 前端：`Flutter`（Dart）
- 后端（开发/测试）：`Python`（位于 `dog/` 目录下的 `dog_server.py` 与 `webrtc_server.py`）
- 媒体与本地数据：项目内 `assets/` 和 `uploads/` 目录用于存放演示或测试数据

### 项目结构（简要）
- `lib/`：Flutter 应用源码，入口 `main.dart`，以及 `screens/`、`services/` 等子模块
- `dog/`：用于本地开发的 Python 服务与演示脚本（例如：`dog_server.py`, `webrtc_server.py`）
- `assets/`：应用使用的静态资源（视频、图片）
- `android/`, `ios/`, `web/`, `windows/`, `macos/`, `linux/`：平台相关工程文件
