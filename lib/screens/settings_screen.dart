import 'package:flutter/material.dart';
import '../services/api.dart';

class SettingsScreen extends StatefulWidget {
  final String? initialServerUrl;
  final void Function(String)? onServerUrlSaved;
  const SettingsScreen({Key? key, this.initialServerUrl, this.onServerUrlSaved}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _serverController;

  @override
  void initState() {
    super.initState();
    _serverController = TextEditingController(text: widget.initialServerUrl ?? Api.serverUrl);
  }

  @override
  void dispose() {
    _serverController.dispose();
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

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              const ListTile(title: Text('应用设置')),
              TextField(controller: _serverController, decoration: const InputDecoration(labelText: '服务器地址')),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _save, child: const Text('保存设置')),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        const Card(
          child: ListTile(
            title: Text('应用信息'),
            subtitle: Text('机器狗APP v1.0.0\n基于Flutter实现'),
          ),
        ),
      ]),
    );
  }
}