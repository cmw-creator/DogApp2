import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api.dart';
import '../services/local_store.dart';

enum SettingsUserType { patient, family }

class SettingsScreen extends StatefulWidget {
  final String? initialServerUrl;
  final void Function(String)? onServerUrlSaved;
  final SettingsUserType userType;
  final String? patientCode;
  final String? bindCode;
  final String? boundPatientCode;
  final Future<void> Function(String patientCode, String bindCode)? onBindPatient;
  final Future<void> Function()? onRegenerateBindCode;
  final VoidCallback? onLogout;

  const SettingsScreen({
    Key? key,
    this.initialServerUrl,
    this.onServerUrlSaved,
    this.userType = SettingsUserType.patient,
    this.patientCode,
    this.bindCode,
    this.boundPatientCode,
    this.onBindPatient,
    this.onRegenerateBindCode,
    this.onLogout,
  }) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _serverController;
  late TextEditingController _patientCodeController;
  late TextEditingController _bindCodeController;
  bool _binding = false;
  String? _bindMessage;
  late double _fontScale;

  @override
  void initState() {
    super.initState();
    _serverController = TextEditingController(text: widget.initialServerUrl ?? Api.serverUrl);
    _patientCodeController = TextEditingController();
    _bindCodeController = TextEditingController();
    _fontScale = LocalStore.fontScale;
  }

  Future<void> _bindPatient() async {
    if (widget.onBindPatient == null) return;
    final pCode = _patientCodeController.text.trim();
    final bCode = _bindCodeController.text.trim();
    if (pCode.isEmpty || bCode.isEmpty) {
      setState(() => _bindMessage = '请输入患者码和绑定验证码');
      return;
    }
    setState(() {
      _binding = true;
      _bindMessage = null;
    });
    await widget.onBindPatient!(pCode, bCode);
    if (mounted) {
      setState(() {
        _binding = false;
        _bindMessage = '绑定请求已提交';
      });
    }
  }

  @override
  void dispose() {
    _serverController.dispose();
    _patientCodeController.dispose();
    _bindCodeController.dispose();
    super.dispose();
  }

  void _save() {
    final url = _serverController.text.trim();
    if (url.isNotEmpty) {
      // 更新 Api 的默认地址（内存），等价于 Kivy 中修改 app.server_url
      Api.serverUrl = url;
      if (widget.onServerUrlSaved != null) widget.onServerUrlSaved!(url);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('设置已保存')));
    }
  }

  // 检查服务器状态
  Future<Map<String, dynamic>?> checkServer() async {
    try {
      final data = await Api.getStatus();
      return data;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        if (widget.userType == SettingsUserType.patient)
          _buildPatientCodesCard(),
        if (widget.userType == SettingsUserType.patient)
          _buildFontScaleCard(),
        if (widget.userType == SettingsUserType.family)
          _buildBindCard(),
        if (widget.userType == SettingsUserType.family)
          const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              const ListTile(title: Text('应用设置')),
              SwitchListTile(
                title: const Text('开发者模式'),
                value: LocalStore.devMode,
                onChanged: (val) {
                  setState(() {
                    LocalStore.devMode = val;
                  });
                },
              ),
              if (LocalStore.devMode) ...[
                TextField(
                  controller: _serverController,
                  decoration: const InputDecoration(labelText: '服务器地址'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: ElevatedButton(onPressed: _save, child: const Text('保存设置'))),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () async {
                        final status = await checkServer();
                        if (mounted) {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('服务器状态'),
                              content: Text(status != null ? '在线' : '无法连接'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('确定'),
                                ),
                              ],
                            ),
                          );
                        }
                      },
                      child: const Text('检查服务器'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildTestNotificationButton(),
              ],
              if (!LocalStore.devMode) ...[
                const SizedBox(height: 12),
                _buildTestNotificationButton(),
              ],
            ]),
          ),
        ),
        const SizedBox(height: 12),
        // 服务器检查已整合到开发者模式设置中
        const SizedBox(height: 12),
        const Card(
          child: ListTile(
            title: Text('应用信息'),
            subtitle: Text('机器狗APP v2.1.0\n基于Flutter实现'),
          ),
        ),
        if (widget.userType == SettingsUserType.family && widget.onLogout != null) ...[
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
            label: const Text('退出登录'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
          ),
        ],
      ]),
    );
  }

  Widget _buildPatientCodesCard() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ListTile(title: Text('患者绑定信息')),
              ListTile(
                leading: const Icon(Icons.qr_code_2),
                title: const Text('用户码'),
                subtitle: Text(widget.patientCode ?? '未生成'),
                trailing: IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () {
                    final code = widget.patientCode ?? '';
                    if (code.isNotEmpty) {
                      Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('用户码已复制')));
                    }
                  },
                ),
              ),
              ListTile(
                leading: const Icon(Icons.lock_open),
                title: const Text('绑定验证码'),
                subtitle: Text(widget.bindCode ?? '未生成'),
                trailing: IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () async {
                    if (widget.onRegenerateBindCode != null) {
                      await widget.onRegenerateBindCode!();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已重新生成验证码')));
                      }
                    }
                  },
                ),
              ),
              const SizedBox(height: 4),
              const Text('将“用户码 + 绑定验证码”提供给家属，在家属端设置中完成绑定。'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBindCard() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ListTile(title: Text('绑定患者')),
              TextField(
                controller: _patientCodeController,
                decoration: const InputDecoration(labelText: '患者用户码'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _bindCodeController,
                decoration: const InputDecoration(labelText: '绑定验证码'),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _binding ? null : _bindPatient,
                icon: const Icon(Icons.link),
                label: Text(_binding ? '绑定中...' : '绑定患者'),
              ),
              const SizedBox(height: 8),
              if (widget.boundPatientCode != null)
                Text('当前已绑定: ${widget.boundPatientCode}', style: const TextStyle(color: Colors.green)),
              if (_bindMessage != null)
                Text(_bindMessage!, style: const TextStyle(color: Colors.blueGrey)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFontScaleCard() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ListTile(title: Text('字体大小')),
              Slider(
                min: 0.9,
                max: 1.5,
                divisions: 6,
                value: _fontScale,
                label: _fontScale.toStringAsFixed(2),
                onChanged: (v) {
                  setState(() {
                    _fontScale = v;
                    LocalStore.fontScale = v;
                  });
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('较小'),
                    Text('默认'),
                    Text('较大'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '默认字体已调大，您可按需调整。',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTestNotificationButton() {
    return ElevatedButton.icon(
      icon: const Icon(Icons.notifications_active),
      label: const Text('测试通知'),
      onPressed: () async {
        final from = widget.userType == SettingsUserType.patient ? 'patient' : 'family';
        final receipt = await Api.publishNotificationWithReceipt(
          message: '这是一条测试通知',
          type: 'test',
          from: from,
          to: 'peer',
          payload: {'from': from},
        );
        final ok = receipt != null;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text(ok ? '已发送（可送达=${receipt?['delivered_possible']}）' : '发送失败'),
            ),
          );
        }
      },
    );
  }
}