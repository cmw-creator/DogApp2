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
    final theme = Theme.of(context);
    
    return RefreshIndicator(
      onRefresh: refreshStatus,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 顶部设备状态卡片
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: online ? Colors.green.shade300 : Colors.grey.shade300,
                  width: 1.5,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white,
                ),
                padding: const EdgeInsets.all(20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: online ? Colors.green.shade100 : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.pets,
                        size: 40,
                        color: online ? Colors.green.shade700 : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '我的小影',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            online ? '✓ 在线' : '✗ 离线',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: online ? Colors.green.shade700 : Colors.red.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 电池卡片
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
                        Icon(Icons.battery_full, color: Colors.orange.shade700),
                        const SizedBox(width: 8),
                        Text(
                          '电池电量',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: battery / 100,
                        minHeight: 8,
                        backgroundColor: Colors.grey.shade300,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          battery > 50 ? Colors.green : (battery > 20 ? Colors.orange : Colors.red),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$battery%  ·  剩余约${((battery / 100 * 3).toStringAsFixed(1))}小时',
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 位置卡片
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
                    const SizedBox(height: 8),
                    Text(
                      location,
                      style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey.shade800),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 对话记录卡片
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.chat_bubble, color: Colors.purple.shade700),
                            const SizedBox(width: 8),
                            Text(
                              '对话记录',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        if (dialogs.isNotEmpty)
                          TextButton.icon(
                            onPressed: () => setState(() => dialogs.clear()),
                            icon: const Icon(Icons.close, size: 18),
                            label: const Text('清除'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (dialogs.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          '暂无对话',
                          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      ...dialogs.reversed.take(5).map(
                        (d) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: d['type'] == 'command'
                                  ? Colors.blue.shade50
                                  : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  d['type'] == 'command' ? '您说：' : '小影回复：',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: d['type'] == 'command'
                                        ? Colors.blue.shade700
                                        : Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  d['message'] ?? '',
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 命令输入区
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.edit, color: Colors.grey.shade600, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _cmdController,
                          decoration: InputDecoration(
                            hintText: '输入指令或问题...',
                            border: InputBorder.none,
                            hintStyle: TextStyle(color: Colors.grey.shade500),
                          ),
                          maxLines: null,
                        ),
                      ),
                      IconButton(
                        onPressed: _loading
                            ? null
                            : () {
                                final text = _cmdController.text;
                                _cmdController.clear();
                                sendDialogMessage(text);
                              },
                        icon: Icon(
                          Icons.send,
                          color: _loading ? Colors.grey.shade400 : Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 快速操作按钮
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : refreshStatus,
                    icon: const Icon(Icons.refresh),
                    label: const Text('刷新'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : sendReturnHome,
                    icon: const Icon(Icons.home),
                    label: const Text('返回充电'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}