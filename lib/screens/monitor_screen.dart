import 'package:flutter/material.dart';
import '../services/api.dart';

class MonitorScreen extends StatelessWidget {
  const MonitorScreen({Key? key}) : super(key: key);

  Future<Map<String, dynamic>?> checkServer() async {
    try {
      // 直接使用 /status 与 DogScreen 保持一致
      final data = await Api.getStatus();
      return data;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Column(children: [
        const TabBar(tabs: [
          Tab(text: '实时'),
          Tab(text: '提醒'),
          Tab(text: '视频'),
          Tab(text: '指令'),
          Tab(text: '看板'),
        ]),
        Expanded(
          child: TabBarView(children: [
            Center(
              child: ElevatedButton(
                onPressed: () async {
                  final status = await checkServer();
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
                },
                child: const Text('检查服务器'),
              ),
            ),
            const Center(child: Text('提醒与警报 - 占位')),
            const Center(child: Text('视频通话 - 占位')),
            const Center(child: Text('指令发送 - 占位')),
            const Center(child: Text('数据看板 - 占位')),
          ]),
        )
      ]),
    );
  }
}