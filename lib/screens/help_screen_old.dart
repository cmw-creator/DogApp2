import 'package:flutter/material.dart';
import '../services/api.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({Key? key}) : super(key: key);

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  String currentLocation = '定位中...';
  String homeAddress = '未设置家庭地址';
  bool _loading = false;

  Future<void> loadFamilyInfo() async {
    setState(() => _loading = true);
    try {
      final data = await Api.getFamilyInfo();
      if (data != null) {
        setState(() {
          homeAddress = (data['address'] ?? homeAddress).toString();
          final loc = data['current_location'];
          if (loc != null) currentLocation = loc.toString();
        });
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> triggerSOS() async {
    setState(() => _loading = true);
    final sosData = {
      'type': 'emergency_alert',
      'message': '用户触发了SOS紧急求助！',
      'location': currentLocation,
      'home_address': homeAddress,
      'timestamp': DateTime.now().toIso8601String(),
    };
    final ok = await Api.sendSos(sosData);
    setState(() => _loading = false);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ok ? 'SOS已发送' : '发送失败'),
        content: Text(ok ? '紧急求助信号已发送！' : '无法发送，请检查网络'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void showLocationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('位置播报'),
        content: Text('$currentLocation\n$homeAddress'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void showNavigateDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('导航回家'),
        content: Text('启动导航到：$homeAddress'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    loadFamilyInfo();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Card(
          color: Colors.red.shade400,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: InkWell(
              onTap: _loading ? null : triggerSOS,
              child: SizedBox(
                width: double.infinity,
                height: 120,
                child: Center(
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          'SOS\n紧急求助',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            title: const Text('当前位置'),
            subtitle: Text(currentLocation),
            trailing: ElevatedButton(
              onPressed: showLocationDialog,
              child: const Text('播报'),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            title: const Text('回家导航'),
            subtitle: Text(homeAddress),
            trailing: ElevatedButton(
              onPressed: showNavigateDialog,
              child: const Text('导航'),
            ),
          ),
        ),
      ]),
    );
  }
}