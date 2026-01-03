import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('家属端登录/注册')),
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
            ToggleButtons(
              borderRadius: BorderRadius.circular(8),
              isSelected: [_isLogin, !_isLogin],
              onPressed: (idx) {
                setState(() {
                  _isLogin = idx == 0;
                  _error = null;
                });
              },
              children: const [
                Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('登录')),
                Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('注册')),
              ],
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
              obscureText: true,
              decoration: const InputDecoration(labelText: '密码'),
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
            const SizedBox(height: 8),
            Text(
              '提示：本示例为本地存储演示，手机号+密码保存在本地。',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
