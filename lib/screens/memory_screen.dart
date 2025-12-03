import 'package:flutter/material.dart';
import '../services/api.dart';

class MemoryScreen extends StatefulWidget {
  const MemoryScreen({Key? key}) : super(key: key);

  @override
  State<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen> {
  List<Map<String, dynamic>> memories = [];

  @override
  void initState() {
    super.initState();
    // 目前使用示例数据；可扩展为从 /get_photo_info 获取
    memories = [
      {
        'date': '2023-12-25',
        'title': '圣诞节家庭聚会',
        'description': '全家一起装饰圣诞树，共享丰盛晚餐',
        'media_type': 'image',
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    final first = memories.isNotEmpty ? memories.first : null;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        const Card(
          child: ListTile(
            title: Text('家庭回忆'),
            subtitle: Text('核心家庭成员与历史上的今天'),
          ),
        ),
        const SizedBox(height: 12),
        if (first != null)
          Card(
            child: ListTile(
              title: Text(first['title'] ?? '无回忆'),
              subtitle: Text(first['description'] ?? ''),
            ),
          )
        else
          const Card(
            child: ListTile(title: Text('当前没有回忆条目')),
          ),
      ]),
    );
  }
}