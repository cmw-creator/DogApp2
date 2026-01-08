import 'dart:async';
import 'package:flutter/material.dart';
import '../services/local_store.dart';
import '../services/api.dart';

class AuthScreen extends StatefulWidget {
  final Future<bool> Function(String phone, String password) onLogin;
  final Future<bool> Function(String phone, String password) onRegister;

  const AuthScreen({Key? key, required this.onLogin, required this.onRegister}) : super(key: key);

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true;
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;
  final _phoneController = TextEditingController();
  final _pwdController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    _pwdController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final phone = _phoneController.text.trim();
    final pwd = _pwdController.text.trim();
    if (phone.isEmpty || pwd.isEmpty) {
      setState(() => _error = '手机号和密码不能为空');
      return;
    }
    if (!_isLogin && !RegExp(r'^1\d{10}$').hasMatch(phone)) {
      setState(() => _error = '手机号格式不正确，需要11位数字且以1开头');
      return;
    }
    if (!_isLogin && pwd.length < 6) {
      setState(() => _error = '密码长度需至少6位');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    bool ok;
    if (_isLogin) {
      ok = await widget.onLogin(phone, pwd);
      if (!ok) setState(() => _error = '手机号或密码不正确');
    } else {
      ok = await widget.onRegister(phone, pwd);
      if (!ok) setState(() => _error = '注册失败，请稍后再试');
    }
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isLogin ? '登录成功' : '注册成功')),
      );
    }
    if (mounted) setState(() => _loading = false);
  }

  void _showServerSettings() {
    final controller = TextEditingController(text: Api.serverUrl);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('服务器设置'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'API 地址',
            hintText: 'http://20.89.159.15:8080',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final url = controller.text.trim();
              if (url.isNotEmpty) {
                Api.serverUrl = url;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('服务器地址已更新')),
                );
              }
              Navigator.pop(context);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _handleSocialLogin(String provider) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Text('正在跳转 $provider 登录...'),
            ],
          ),
        ),
      ),
    );

    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    Navigator.pop(context); // Close loading dialog

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$provider 登录失败，请稍后重试')),
    );
  }

  void _showSmsLoginDialog() {
    showDialog(
      context: context,
      builder: (context) => const _SmsLoginDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('欢迎'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'server') _showServerSettings();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'server',
                child: Text('服务器设置'),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(theme),
            const SizedBox(height: 16),
            _buildCard(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '欢迎使用家属端',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '登录或注册以管理患者和查看监控',
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.blue.shade700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(ThemeData theme) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isLogin ? '登录账号' : '注册新账号',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: '手机号'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pwdController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: '密码',
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
            Row(
              children: [
                if (_isLogin)
                  TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('请联系管理员重置密码')),
                      );
                    },
                    child: const Text('忘记密码？'),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isLogin = !_isLogin;
                      _error = null;
                    });
                  },
                  child: Text(_isLogin ? '注册账号' : '已有账号？点击登录'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ElevatedButton.icon(
              onPressed: _loading ? null : _submit,
              icon: Icon(_isLogin ? Icons.login : Icons.person_add),
              label: Text(_isLogin ? '登录' : '注册'),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
            
            if (_isLogin) ...[
              const SizedBox(height: 24),
              const Row(children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('其他登录方式', style: TextStyle(color: Colors.grey)),
                ),
                Expanded(child: Divider()),
              ]),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _SocialIcon(
                    icon: Icons.message,
                    label: '短信登录',
                    onTap: _showSmsLoginDialog,
                    color: Colors.blue,
                  ),
                  _SocialIcon(
                    icon: Icons.chat,
                    label: '微信',
                    onTap: () => _handleSocialLogin('微信'),
                    color: Colors.green,
                  ),
                  _SocialIcon(
                    icon: Icons.apple,
                    label: 'Apple',
                    onTap: () => _handleSocialLogin('Apple ID'),
                    color: Colors.black,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SocialIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _SocialIcon({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _SmsLoginDialog extends StatefulWidget {
  const _SmsLoginDialog();

  @override
  State<_SmsLoginDialog> createState() => _SmsLoginDialogState();
}

class _SmsLoginDialogState extends State<_SmsLoginDialog> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  int _countdown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _sendCode() {
    final phone = _phoneController.text.trim();
    if (!RegExp(r'^1\d{10}$').hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入正确的手机号')),
      );
      return;
    }

    setState(() {
      _countdown = 60;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('验证码已发送（模拟：123456）')),
    );
  }

  void _login() {
    final phone = _phoneController.text.trim();
    final code = _codeController.text.trim();

    if (phone.isEmpty || code.isEmpty) {
      return;
    }

    // Mock login check
    if (code == '123456') {
      // In a real app, we would call the login API here.
      // Since the user asked for "cannot real login", we just show a message.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('验证码正确，但此功能仅为演示')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('验证码错误')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('手机号一键登录'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: '手机号',
              prefixIcon: Icon(Icons.phone_android),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '验证码',
                    prefixIcon: Icon(Icons.security),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _countdown > 0 ? null : _sendCode,
                child: Text(_countdown > 0 ? '${_countdown}s' : '发送验证码'),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _login,
          child: const Text('登录'),
        ),
      ],
    );
  }
}
