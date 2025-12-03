import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// 导入拆分后的页面
import 'screens/dog_screen.dart';
import 'screens/today_screen.dart';
import 'screens/memory_screen.dart';
import 'screens/help_screen.dart';
import 'screens/manage_screen.dart';
import 'screens/monitor_screen.dart';
import 'screens/settings_screen.dart';
import 'services/api.dart';

void main() async {
  // 尝试启动本地测试后端（桌面调试时模拟 Kivy 中在 __main__ 里启动 DogServer）
  startTestBackend();

  runApp(const MyApp());
}

// 用于保存启动的后台进程引用（仅在支持的桌面平台有效）
Process? _backendProcess;

/// 尝试启动测试后端 dog/dog_server.py（仅在桌面环境）
Future<void> startTestBackend() async {
  if (kIsWeb) return;
  if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    debugPrint('startTestBackend: 非桌面平台，跳过启动测试后端');
    return;
  }

  final scriptPath =
      Platform.isWindows ? 'dog\\dog_server.py' : 'dog/dog_server.py';
  try {
    Process? proc;
    try {
      proc = await Process.start(
        'python3',
        [scriptPath],
        workingDirectory: Directory.current.path,
        mode: ProcessStartMode.detachedWithStdio,
      );
    } catch (_) {
      proc = await Process.start(
        'python',
        [scriptPath],
        workingDirectory: Directory.current.path,
        mode: ProcessStartMode.detachedWithStdio,
      );
    }

    if (proc != null) {
      _backendProcess = proc;
      // 输出后端日志到 Flutter 控制台
      proc.stdout
          .transform(utf8.decoder)
          .listen((data) => debugPrint('[backend] $data'));
      proc.stderr
          .transform(utf8.decoder)
          .listen((data) => debugPrint('[backend][err] $data'));
      debugPrint('测试后端已启动 (pid=${proc.pid})');

      // 在收到 SIGINT / SIGTERM 时尝试终止后端（桌面调试友好）
      try {
        ProcessSignal.sigint.watch().listen((_) {
          debugPrint('收到 SIGINT，尝试停止测试后端');
          stopTestBackend();
        });
        ProcessSignal.sigterm.watch().listen((_) {
          debugPrint('收到 SIGTERM，尝试停止测试后端');
          stopTestBackend();
        });
      } catch (_) {
        // 某些平台/环境不支持信号监听，忽略
      }
    }
  } catch (e) {
    debugPrint('无法启动测试后端: $e');
  }
}

/// 停止测试后端（如果已启动）
void stopTestBackend() {
  try {
    if (_backendProcess != null) {
      _backendProcess!.kill(ProcessSignal.sigterm);
      debugPrint('已发送终止信号到测试后端 (pid=${_backendProcess!.pid})');
      _backendProcess = null;
    }
  } catch (e) {
    debugPrint('停止测试后端时出错: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // 简单主题与入口
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '机器狗 Flutter 迁移示例',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const RootPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class RootPage extends StatefulWidget {
  const RootPage({Key? key}) : super(key: key);

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  // 模拟用户类型：'family' 或 'patient'
  String userType = 'family';
  int _currentIndex = 0;

  // 服务器地址可在 Settings 页面修改（这里是内存保存示例）
  String serverUrl = 'http://127.0.0.1:5000';

  // 根据 userType 构建页面列表与导航项
  List<Widget> get _patientPages => const [
        DogScreen(),
        TodayScreen(),
        MemoryScreen(),
        HelpScreen(),
        SettingsScreen(),
      ];

  List<BottomNavigationBarItem> get _patientNavItems => const [
        BottomNavigationBarItem(icon: Icon(Icons.pets), label: '机器狗'),
        BottomNavigationBarItem(icon: Icon(Icons.today), label: '今天'),
        BottomNavigationBarItem(icon: Icon(Icons.photo_library), label: '回忆'),
        BottomNavigationBarItem(icon: Icon(Icons.help), label: '求助'),
        BottomNavigationBarItem(icon: Icon(Icons.settings), label: '设置'),
      ];

  List<Widget> get _familyPages => [
        ManageScreen(onServerUrlChanged: (url) {
          setState(() {
            serverUrl = url;
            Api.serverUrl = url;
          });
        }),
        const MonitorScreen(),
        SettingsScreen(
          initialServerUrl: serverUrl,
          onServerUrlSaved: (url) {
            setState(() {
              serverUrl = url;
              Api.serverUrl = url;
            });
          },
        ),
      ];

  List<BottomNavigationBarItem> get _familyNavItems => const [
        BottomNavigationBarItem(icon: Icon(Icons.group), label: '管理'),
        BottomNavigationBarItem(icon: Icon(Icons.monitor), label: '监控'),
        BottomNavigationBarItem(icon: Icon(Icons.settings), label: '设置'),
      ];

  @override
  Widget build(BuildContext context) {
    final pages = userType == 'patient' ? _patientPages : _familyPages;
    final navItems = userType == 'patient' ? _patientNavItems : _familyNavItems;

    return Scaffold(
      appBar: AppBar(
        title: Text(userType == 'patient' ? '患者端' : '家属端'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'switch') {
                setState(() {
                  userType = (userType == 'patient') ? 'family' : 'patient';
                  _currentIndex = 0;
                });
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'switch', child: Text('切换用户类型')),
            ],
          )
        ],
      ),
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        items: navItems,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
