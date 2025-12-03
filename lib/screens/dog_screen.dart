import 'package:flutter/material.dart';
import '../services/api.dart';

class DogScreen extends StatefulWidget {
  const DogScreen({Key? key}) : super(key: key);

  @override
  State<DogScreen> createState() => _DogScreenState();
}

class _DogScreenState extends State<DogScreen> {
  int battery = 75;
  String location = '正在获取位置信息...';
  List<Map<String, String>> dialogs = [];
  bool online = true;
  bool _loading = false;

  final TextEditingController _cmdController = TextEditingController();

  Future<void> refreshStatus() async {
    setState(() => _loading = true);
    try {
      final data = await Api.getStatus();
      if (data != null) {
        setState(() {
          online = true;
          battery = (data['battery']?['level'] as int?) ?? battery;
          final loc = data['location'];
          location = loc != null ? loc.toString() : location;
          final dialogHistory = data['dialog_history'] as List<dynamic>?;
          if (dialogHistory != null) {
            dialogs = dialogHistory.map((e) {
              return {
                'type': (e['type'] ?? 'reply').toString(),
                'message': (e['message'] ?? '').toString(),
                'time': (e['timestamp'] ?? '').toString(),
              };
            }).toList();
          }
        });
      } else {
        setState(() => online = false);
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> sendReturnHome() async {
    setState(() => _loading = true);
    final ok = await Api.returnHome();
    setState(() => _loading = false);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ok ? '指令已发送' : '指令失败'),
        content: Text(ok ? '机器狗正在返回充电...' : '发送失败，请重试'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (ok) await refreshStatus();
  }

  Future<void> sendDialogMessage(String message) async {
    if (message.trim().isEmpty) return;
    setState(() => _loading = true);
    final ok = await Api.sendCommand(message);
    setState(() => _loading = false);
    if (ok) {
      await refreshStatus();
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('发送失败'),
          content: const Text('无法发送指令'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('确定'),
            ),
          ],
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    refreshStatus();
  }

  @override
  void dispose() {
    _cmdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: refreshStatus,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: ListTile(
                title: const Text(
                  '我的小影',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(online ? '在线' : '离线'),
                trailing: const CircleAvatar(child: Icon(Icons.pets)),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                title: const Text('状态'),
                subtitle: Text(_loading ? '加载中...' : (online ? '正常' : '离线')),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🔋 电池电量',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: battery / 100),
                    const SizedBox(height: 8),
                    Text('$battery%   剩余时间: 约3小时'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('📍 当前位置',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text(location),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('💬 对话记录',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        TextButton(
                          onPressed: () => setState(() => dialogs.clear()),
                          child: const Text('清除'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (dialogs.isEmpty) const Text('暂无对话记录'),
                    ...dialogs.reversed.map(
                      (d) => ListTile(
                        leading: Icon(
                          d['type'] == 'command'
                              ? Icons.send
                              : Icons.smart_toy,
                        ),
                        title: Text(d['message'] ?? ''),
                        subtitle: Text(d['time'] ?? ''),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _cmdController,
                  decoration:
                      const InputDecoration(hintText: '输入指令...'),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  final text = _cmdController.text;
                  _cmdController.clear();
                  sendDialogMessage(text);
                },
                child: const Icon(Icons.send),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: refreshStatus,
                  child: const Text('🔄 刷新状态'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: sendReturnHome,
                  child: const Text('🏠 返回充电'),
                ),
              ),
            ]),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}