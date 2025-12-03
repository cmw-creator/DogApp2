import 'package:flutter/material.dart';
import '../services/api.dart';

// 今天页：日期、天气、日程
class TodayScreen extends StatefulWidget {
  const TodayScreen({Key? key}) : super(key: key);

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  String dateStr = '';
  String weather = '天气信息加载中...';
  final List<String> _schedules = [];
  String? _importantMessage; // 新增：重要提醒文本

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    dateStr =
        '${now.year}年${now.month.toString().padLeft(2, '0')}月${now.day.toString().padLeft(2, '0')}日';
    // 目前用本地模拟；若后端提供天气接口可在此调用 Api.xxx
    weather = '晴转多云 25°C/18°C 东南风2级';
    _schedules.addAll(<String>[
      '09:00 - 10:30 晨间散步',
      '14:00 - 15:00 午休时间',
      '16:30 - 17:30 户外活动',
      '19:00 - 20:00 晚餐时间',
    ]);
    _loadImportantMessage();
  }

  Future<void> _loadImportantMessage() async {
    final data = await Api.getImportantMessage();
    if (!mounted) return;
    setState(() {
      _importantMessage = data?['message'];
      if (_importantMessage != null && _importantMessage!.trim().isEmpty) {
        _importantMessage = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        // 下拉刷新时也重新拉取提醒（可选）
        await _loadImportantMessage();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Card(
            child: ListTile(
              title: const Text('今天'),
              subtitle: Text(dateStr),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              title: const Text('天气'),
              subtitle: Text(weather),
            ),
          ),
          const SizedBox(height: 12),
          if (_importantMessage != null) ...[
            Card(
              color: Colors.orange.shade100,
              child: ListTile(
                leading: const Icon(Icons.campaign, color: Colors.orange),
                title: const Text(
                  '重要提醒',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(_importantMessage!),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Card(
            child: Column(
              children: [
                const ListTile(title: Text('今日日程')),
                const Divider(height: 1),
                if (_schedules.isEmpty)
                  const ListTile(title: Text('暂无日程')),
                ..._schedules.map((e) => ListTile(title: Text(e))),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}