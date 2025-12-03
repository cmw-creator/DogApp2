# flutter开发环境的安卓

## flutter手动安装：

[手动安装 | Flutter 框架](https://docs.fluttercn.cn/install/manual)

安装成功验证，cmd.exe运行：

```cmd.exe
flutter --version
dart --version
```

**针对国内用户**：为了加速包和工具的下载，建议配置以下环境变量

[在中国网络环境下使用 Flutter](https://docs.flutter.cn/community/china/)

```
PUB_HOSTED_URL=https://mirrors.tuna.tsinghua.edu.cn/dart-pub
FLUTTER_STORAGE_BASE_URL=https://mirrors.tuna.tsinghua.edu.cn/flutter
```

## java环境(可选)

在edge里打开不需要，打包成apk需要

### 安装jdk 17

[Java Archive Downloads - Java SE 17.0.12 and earlier](https://www.oracle.com/java/technologies/javase/jdk17-archive-downloads.html)

### 验证，cmd.exe运行：

```
java --version
```

## IDE配置，以下两种选一个

## VS code

### 对于VS code，安装插件

**Flutter**：安装此插件时会**自动安装 Dart 插件**

~~此外，你还可以考虑安装一些提升效率的辅助插件，如 `Awesome Flutter Snippets`（代码片段）和 `Error Lens`（增强错误提示）。~~

尤其推荐使用安装**trae**插件或使用**copilot**。 [trae官网](https://www.trae.cn/)  [github copilot](https://blog.csdn.net/PGJ_168/article/details/150267222)

### 插件验证

在 VS Code 中，通过快捷键 `Ctrl+Shift+P`(Windows/Linux) 或 `Cmd+Shift+P`(macOS) 打开命令面板，输入并执行 `Flutter: Run Flutter Doctor`命令 。这会在输出窗口显示一份详细的环境健康报告，它会明确指出缺失的依赖或未同意的协议。
### 运行

打开项目文件夹，在左侧选择“运行和调试”，点击Dart & Flutter，选择Flutter Edge，利用浏览器打开

![1](C:\Users\97266\Desktop\人机交互\DogApp2\doc\pic\1.png)


## 使用Android Studio和安卓模拟器

1.访问 Android Studio 官网下载安装程序，并完成安装。

2.首次打开后进行配置，可以全默认。(选custom就下载全勾上)

3.安装开发插件:Flutter 和 Dart

4.**安装系统镜像**：在 **SDK Manager**中，切换到 **SDK Platforms**选项卡，选择你需要的 Android 版本（例如 Android 14）进行安装。应该自带一个Android 16的环境，推荐使用api29(Android 10)的环境。

5.设置sdk环境 flutter config --android-sdk C:\Development\Android\sdk

6.启动安卓模拟器，选择该设备，运行。

 Android Studio同样支持edge浏览器模式，选择edge运行即可

