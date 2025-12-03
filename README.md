# Flutter开发环境配置

* 安装前注意：很多包国内环境不好下载，可能开全局梯子或者要配置一些镜像

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

尤其推荐使用安装**trae**插件或使用**copilot**。 [trae官网](https://www.trae.cn/)  [github copilot](https://blog.csdn.net/PGJ_168/article/details/150267222)

### 插件验证

在 VS Code 中，通过快捷键 `Ctrl+Shift+P`(Windows/Linux) 或 `Cmd+Shift+P`(macOS) 打开命令面板，输入并执行 `Flutter: Run Flutter Doctor`命令 。这会在输出窗口显示一份详细的环境健康报告，它会明确指出缺失的依赖或未同意的协议。
### 运行

打开项目文件夹，在左侧选择“运行和调试”，点击Dart & Flutter，选择Flutter Edge，利用浏览器打开

![1](C:\Users\97266\Desktop\人机交互\DogApp2\doc\pic\1.png)

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

### 4.1 启动后端(非必须)
运行dog/dog_server.py，怎么运行都行。
### 4.2 启动前端
直接参考IDE启动即可

## 5 打包成本地apk

```
flutter build apk --release
```
## 6 常见问题
