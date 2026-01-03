import 'dart:async';
import 'package:flutter/material.dart';
import '../services/notification_service.dart';

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({Key? key}) : super(key: key);

  @override
  State<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  late List<Map<String, dynamic>> _items;
  StreamSubscription<Map<String, dynamic>>? _sub;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _items = NotificationService.instance.historySnapshot;
    NotificationService.instance.start();
    _refresh();
    _sub = NotificationService.instance.stream.listen((event) {
      setState(() {
        _items = NotificationService.instance.historySnapshot;
      });
    });
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final history = await NotificationService.instance.fetchHistory(limit: 100);
      if (!mounted) return;
      setState(() {
        _items = history;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('通知中心'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: _items.isEmpty
          ? Center(
              child: _loading
                  ? const CircularProgressIndicator()
                  : const Text('暂无通知'),
            )
          : ListView.builder(
              itemCount: _items.length,
              itemBuilder: (ctx, i) {
                final item = _items[_items.length - 1 - i]; // 逆序显示最新在上
                final type = item['type']?.toString() ?? 'info';
                final message = item['message']?.toString() ?? '';
                final ts = item['timestamp']?.toString() ?? '';
                return ListTile(
                  leading: Icon(_iconForType(type), color: theme.colorScheme.primary),
                  title: Text(message),
                  subtitle: Text('$type · $ts'),
                );
              },
            ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'sos':
        return Icons.warning_amber_rounded;
      case 'schedule':
        return Icons.schedule;
      case 'test':
        return Icons.notification_add;
      default:
        return Icons.notifications;
    }
  }
}
