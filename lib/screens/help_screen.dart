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
    final theme = Theme.of(context);
    
    return RefreshIndicator(
      onRefresh: () => loadFamilyInfo(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 紧急求助按钮（醒目卡片）
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.red.shade400, width: 2),
              ),
              child: InkWell(
                onTap: _loading ? null : triggerSOS,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.red.shade50,
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      if (_loading)
                        CircularProgressIndicator(color: Colors.red.shade700)
                      else
                        Column(
                          children: [
                            Icon(Icons.emergency, size: 64, color: Colors.red.shade700),
                            const SizedBox(height: 12),
                            Text(
                              '紧急求助',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: Colors.red.shade900,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '长按或点击发送紧急信号',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.red.shade700,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 提示文本
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                border: Border.all(color: Colors.amber.shade300, width: 1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info, color: Colors.amber.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '遇到紧急情况时，点击上方按钮发送求助信号，家属将收到您的位置和紧急信息。',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 位置信息卡片
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200, width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.location_on, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Text(
                          '当前位置',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentLocation,
                            style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: ElevatedButton.icon(
                              onPressed: showLocationDialog,
                              icon: const Icon(Icons.volume_up, size: 18),
                              label: const Text('播报位置'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 导航卡片
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200, width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.home, color: Colors.green.shade700),
                        const SizedBox(width: 8),
                        Text(
                          '回家导航',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            homeAddress,
                            style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: ElevatedButton.icon(
                              onPressed: showNavigateDialog,
                              icon: const Icon(Icons.directions, size: 18),
                              label: const Text('启动导航'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
