import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'screens/auth_screen.dart';
// 导入拆分后的页面
import 'screens/dog_screen.dart';
import 'screens/today_screen.dart';
import 'screens/memory_screen.dart';
import 'screens/help_screen.dart';
import 'screens/manage_screen.dart';
import 'screens/monitor_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/community_screen.dart';
import 'screens/notification_screen.dart';
import 'services/api.dart';
import 'services/local_store.dart';
import 'services/in_app_notification.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStore.ensureInit();
  // 桌面调试时可手动开启本地测试后端；默认关闭避免无关日志。
  // startTestBackend();

  runApp(const MyApp());
}

// 用于保存启动的后台进程引用（仅在支持的桌面平台有效）
Process? _backendProcess;

/// 尝试启动测试后端 dog/dog_server.py（仅在桌面环境）
Future<void> startTestBackend() async {
  if (kIsWeb) return;
  if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
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
      // 如需查看后端日志，可在这里恢复 stdout/stderr 转发。

      // 在收到 SIGINT / SIGTERM 时尝试终止后端（桌面调试友好）
      try {
        ProcessSignal.sigint.watch().listen((_) => stopTestBackend());
        ProcessSignal.sigterm.watch().listen((_) => stopTestBackend());
      } catch (_) {
        // 某些平台/环境不支持信号监听，忽略
      }
    }
  } catch (e) {
  }
}

/// 停止测试后端（如果已启动）
void stopTestBackend() {
  try {
    if (_backendProcess != null) {
      _backendProcess!.kill(ProcessSignal.sigterm);
      _backendProcess = null;
    }
  } catch (e) {
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
        scaffoldBackgroundColor: Colors.white,
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
        ),
      ),
      home: const RootPage(),
      builder: (context, child) {
        return InAppNotificationOverlay(child: child ?? const SizedBox.shrink());
      },
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
  static const bool _bindingGateEnabled = true; // 需要时可改为 false 关闭绑定强制
  static const bool _showBindTutorialOnLogin = true; // 需要时可改为 false 关闭弹窗教程
  static const bool _showBindPromptOnLogin = true; // 登录后直接弹出绑定输入

  // 模拟用户类型：'family' 或 'patient'
  String userType = 'family';
  int _currentIndex = 0;

  // 登录与绑定状态
  bool _initialized = false;
  bool _familyLoggedIn = false;
  bool _bindTutorialShown = false;
  bool _bindPromptShown = false;
  String? _familyPhone;
  String? _patientCode;
  String? _bindCode;
  String? _boundPatientCode;

  final TextEditingController _bindPatientCodeCtrl = TextEditingController();
  final TextEditingController _bindCodeCtrl = TextEditingController();

  // 服务器地址可在 Settings 页面修改（这里是内存保存示例）
  String serverUrl = 'http://127.0.0.1:5000';

  @override
  void initState() {
    super.initState();
    _initState();

    // 全局订阅通知流并弹窗。避免仅在特定页面监听导致“无弹窗”。
    NotificationService.instance.stream.listen((event) {
      final type = event['type']?.toString() ?? 'info';
      if (type == 'ping' || type == 'hello' || type == 'ack') return;

      final message = event['message']?.toString() ?? '收到新通知';
      InAppNotification.instance.show(
        title: type == 'sos' ? 'SOS' : '通知：$type',
        message: message,
        severity: type == 'sos'
            ? InAppNotificationSeverity.danger
            : InAppNotificationSeverity.info,
        actionLabel: '查看通知',
        onAction: () {
          if (!mounted) return;
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const NotificationCenterScreen()),
          );
        },
      );
    });

    // 等首帧后再标记 UI ready 并启动订阅，避免启动早期事件无人监听而“看起来没反应”。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.instance.setUiReady();
      NotificationService.instance.start();
    });
  }

  @override
  void dispose() {
    _bindPatientCodeCtrl.dispose();
    _bindCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _initState() async {
    await LocalStore.ensureInit();
    setState(() {
      _familyPhone = LocalStore.familyPhone;
      _familyLoggedIn = LocalStore.isLoggedIn;
      _patientCode = LocalStore.patientCode;
      _bindCode = LocalStore.bindCode;
      _boundPatientCode =
          LocalStore.getBoundPatientForAccount(_familyPhone) ?? LocalStore.boundPatientCode;
      _initialized = true;
    });
  }

  Future<void> _handleLogin(String phone, String password) async {
    final ok = await Api.loginUser(phone: phone, password: password);
    if (ok && mounted) {
      await LocalStore.saveSession(phone);
      setState(() {
        _familyLoggedIn = true;
        _familyPhone = phone;
        _boundPatientCode = LocalStore.getBoundPatientForAccount(phone);
      });
      _maybeShowBindPrompt();
    }
  }

  Future<void> _handleRegister(String phone, String password) async {
    final ok = await Api.registerUser(phone: phone, password: password);
    if (ok && mounted) {
      await LocalStore.saveSession(phone);
      setState(() {
        _familyLoggedIn = true;
        _familyPhone = phone;
        _boundPatientCode = LocalStore.getBoundPatientForAccount(phone);
      });
      _maybeShowBindPrompt();
    }
  }

  Future<void> _handleLogout() async {
    await Api.logoutUser();
    await LocalStore.logout();
    if (mounted) {
      setState(() {
        _familyLoggedIn = false;
        _familyPhone = null;
        _currentIndex = 0;
        _boundPatientCode = null;
        _bindTutorialShown = false;
        _bindPromptShown = false;
      });
    }
  }

  Future<void> _handleRegenerateBindCode() async {
    await LocalStore.regenerateBindCode();
    if (mounted) setState(() => _bindCode = LocalStore.bindCode);
  }

  Future<void> _handleBindPatient(String patientCode, String bindCode) async {
    // 简单本地校验：只有与患者端生成的 code 匹配才视为成功
    if (patientCode == LocalStore.patientCode && bindCode == LocalStore.bindCode) {
      final phone = _familyPhone ?? LocalStore.familyPhone ?? '';
      if (phone.isNotEmpty) {
        await LocalStore.setBoundPatientForAccount(phone: phone, code: patientCode);
      } else {
        await LocalStore.setBoundPatient(patientCode);
      }
      if (mounted) {
        setState(() {
          _boundPatientCode = patientCode;
          _currentIndex = 0;
        });
      }
    }
  }

  void _maybeShowBindPrompt() {
    if (!_bindingGateEnabled || !_showBindPromptOnLogin || _bindPromptShown) return;
    if (!_familyLoggedIn) return;
    if (_boundPatientCode != null && _boundPatientCode!.isNotEmpty) return;

    _bindPromptShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _bindPatientCodeCtrl.text = _patientCode ?? '';
      _bindCodeCtrl.text = _bindCode ?? '';
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('绑定患者'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _bindPatientCodeCtrl,
                decoration: const InputDecoration(labelText: '患者码'),
              ),
              TextField(
                controller: _bindCodeCtrl,
                decoration: const InputDecoration(labelText: '绑定码'),
              ),
              const SizedBox(height: 8),
              const Text('提示：患者端设置页可查看患者码与绑定码'),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('稍后')),
            ElevatedButton(
              onPressed: () async {
                await _handleBindPatient(
                  _bindPatientCodeCtrl.text.trim(),
                  _bindCodeCtrl.text.trim(),
                );
                if (mounted) Navigator.pop(context);
              },
              child: const Text('立即绑定'),
            ),
          ],
        ),
      );
    });
  }

  // 根据 userType 构建页面列表与导航项
  List<Widget> get _patientPages => [
        const DogScreen(),
        const TodayScreen(),
        const MemoryScreen(),
        const HelpScreen(),
        SettingsScreen(
          userType: SettingsUserType.patient,
          patientCode: _patientCode,
          bindCode: _bindCode,
          onRegenerateBindCode: _handleRegenerateBindCode,
        ),
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
        const CommunityScreen(),
        SettingsScreen(
          userType: SettingsUserType.family,
          initialServerUrl: serverUrl,
          boundPatientCode: _boundPatientCode,
          onBindPatient: _handleBindPatient,
          onServerUrlSaved: (url) {
            setState(() {
              serverUrl = url;
              Api.serverUrl = url;
            });
          },
          onLogout: _handleLogout,
        ),
      ];

  List<BottomNavigationBarItem> get _familyNavItems => const [
        BottomNavigationBarItem(icon: Icon(Icons.group), label: '管理'),
        BottomNavigationBarItem(icon: Icon(Icons.monitor), label: '监控'),
        BottomNavigationBarItem(icon: Icon(Icons.people), label: '社区'),
        BottomNavigationBarItem(icon: Icon(Icons.settings), label: '设置'),
      ];

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final needsBinding = userType == 'family' && _familyLoggedIn && _bindingGateEnabled &&
        (_boundPatientCode == null || _boundPatientCode!.isEmpty);

    if (needsBinding && _showBindTutorialOnLogin && !_bindTutorialShown) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _bindTutorialShown = true);
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('绑定教程'),
            content: const Text('1) 让患者端展示患者码和绑定码\n2) 在下方输入对应编码\n3) 绑定后家属端功能解锁'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('知道了')),
            ],
          ),
        );
      });
    }

    if (userType == 'family' && !_familyLoggedIn) {
      return AuthScreen(
        onLogin: (phone, pwd) async {
          await _handleLogin(phone, pwd);
          if (mounted && _familyLoggedIn) setState(() => _currentIndex = 0);
          return _familyLoggedIn;
        },
        onRegister: (phone, pwd) async {
          await _handleRegister(phone, pwd);
          if (mounted && _familyLoggedIn) setState(() => _currentIndex = 0);
          return _familyLoggedIn;
        },
      );
    }

    final pages = userType == 'patient'
      ? _patientPages
      : (needsBinding ? [_buildBindRequiredPage(), _buildBindHelpPage()] : _familyPages);
    final navItems = userType == 'patient'
      ? _patientNavItems
      : (needsBinding
        ? const [
          BottomNavigationBarItem(icon: Icon(Icons.link), label: '绑定'),
          BottomNavigationBarItem(icon: Icon(Icons.help_outline), label: '说明'),
          ]
        : _familyNavItems);

    final safeIndex = _currentIndex >= pages.length ? 0 : _currentIndex;

    return Scaffold(
      appBar: AppBar(
        title: Text(userType == 'patient' ? '患者端' : '家属端'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationCenterScreen()),
              );
            },
          ),
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
      body: pages[safeIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: safeIndex,
        items: navItems,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
      ),
    );
  }

  Widget _buildBindRequiredPage() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          const Text('请先绑定患者', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('步骤：'),
                  const SizedBox(height: 8),
                  const Text('1) 在患者端打开“设置”，查看患者码与绑定码'),
                  const Text('2) 将下方两个码填写后点击绑定'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _bindPatientCodeCtrl,
                    decoration: const InputDecoration(labelText: '患者码'),
                  ),
                  TextField(
                    controller: _bindCodeCtrl,
                    decoration: const InputDecoration(labelText: '绑定码'),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await _handleBindPatient(
                        _bindPatientCodeCtrl.text.trim(),
                        _bindCodeCtrl.text.trim(),
                      );
                    },
                    icon: const Icon(Icons.link),
                    label: const Text('绑定患者'),
                  ),
                  const SizedBox(height: 8),
                  Text('当前账户: ${_familyPhone ?? '未登录'}'),
                  Text('患者端示例码: ${_patientCode ?? ''}'),
                  Text('绑定码: ${_bindCode ?? ''}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text('绑定成功后将解锁管理、监控等全部功能。'),
        ],
      ),
    );
  }

  Widget _buildBindHelpPage() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          SizedBox(height: 12),
          Text('绑定说明', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 12),
          Text('1) 在患者端设置页找到“患者码”和“绑定码”'),
          Text('2) 家属端登录后，在绑定页填写上述两个码'),
          Text('3) 绑定成功后解锁管理、监控、社区等全部功能'),
          SizedBox(height: 12),
          Text('小提示：当前为测试环境，患者码与绑定码已固定，方便联调'),
        ],
      ),
    );
  }
}
