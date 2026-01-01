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
  String weekdayStr = '';
  String weather = '天气信息加载中...';
  String weatherIcon = '☀️';
  final List<Map<String, String>> _schedules = [];
  String? _importantMessage;
  String? _importantMessageType;

  @override
  void initState() {
    super.initState();
    _updateDate();
    _loadWeather();
    _loadSchedules();
    _loadImportantMessage();
  }

  void _updateDate() {
    final now = DateTime.now();
    final weekdays = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
    dateStr = '${now.year}年${now.month}月${now.day}日';
    weekdayStr = weekdays[now.weekday - 1];
  }

  void _loadWeather() {
    // 目前用本地模拟；若后端提供天气接口可在此调用 Api.xxx
    weather = '晴转多云 25°C/18°C';
    weatherIcon = '☀️';
  }

  void _loadSchedules() {
    // 解析日程字符串为结构化数据
    final scheduleStrings = [
      '09:00 - 10:30 晨间散步',
      '14:00 - 15:00 午休时间',
      '16:30 - 17:30 户外活动',
      '19:00 - 20:00 晚餐时间',
    ];
    
    _schedules.clear();
    for (var schedule in scheduleStrings) {
      final parts = schedule.split(' ');
      if (parts.length >= 3) {
        _schedules.add({
          'time': parts[0] + ' - ' + parts[2],
          'event': parts.sublist(3).join(' '),
          'completed': 'false',
        });
      }
    }
  }

  Future<void> _loadImportantMessage() async {
    final data = await Api.getImportantMessage();
    if (!mounted) return;
    setState(() {
      _importantMessage = data?['message'];
      _importantMessageType = data?['type'];
      if (_importantMessage != null && _importantMessage!.trim().isEmpty) {
        _importantMessage = null;
      }
    });
  }

  IconData _getWeatherIcon(String weatherText) {
    if (weatherText.contains('晴')) return Icons.wb_sunny;
    if (weatherText.contains('云')) return Icons.cloud;
    if (weatherText.contains('雨')) return Icons.grain;
    if (weatherText.contains('雪')) return Icons.ac_unit;
    return Icons.wb_cloudy;
  }

  Color _getWeatherColor(String weatherText) {
    if (weatherText.contains('晴')) return Colors.orange;
    if (weatherText.contains('云')) return Colors.blueGrey;
    if (weatherText.contains('雨')) return Colors.blue;
    if (weatherText.contains('雪')) return Colors.lightBlue;
    return Colors.grey;
  }

  IconData _getScheduleIcon(String event) {
    if (event.contains('散步') || event.contains('活动')) return Icons.directions_walk;
    if (event.contains('餐')) return Icons.restaurant;
    if (event.contains('休') || event.contains('睡')) return Icons.bedtime;
    if (event.contains('药')) return Icons.medication;
    return Icons.event;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return RefreshIndicator(
      onRefresh: () async {
        await _loadImportantMessage();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 顶部大卡片：日期+星期+天气
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.lightBlue.shade50,
                      Colors.lightBlue.shade100,
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dateStr,
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                weekdayStr,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Icon(
                              _getWeatherIcon(weather),
                              size: 48,
                              color: _getWeatherColor(weather),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              weather,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.blue.shade800,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // 重要提醒（更醒目）
            if (_importantMessage != null) ...[
              Card(
                elevation: 3,
                color: Colors.orange.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.orange.shade300, width: 2),
                ),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.campaign,
                          color: Colors.orange.shade700,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '重要提醒',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _importantMessage!,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: Colors.orange.shade800,
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
            ],
            
            // 今日日程（时间线样式）
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          color: theme.colorScheme.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '今日日程',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  if (_schedules.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.event_busy,
                              size: 48,
                              color: theme.colorScheme.onSurface.withOpacity(0.3),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '暂无日程安排',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...List.generate(_schedules.length, (index) {
                      final schedule = _schedules[index];
                      final isLast = index == _schedules.length - 1;
                      final isCompleted = schedule['completed'] == 'true';
                      
                      return _buildScheduleItem(
                        schedule: schedule,
                        isLast: isLast,
                        isCompleted: isCompleted,
                        theme: theme,
                      );
                    }),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleItem({
    required Map<String, String> schedule,
    required bool isLast,
    required bool isCompleted,
    required ThemeData theme,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 时间线
          Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.secondaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getScheduleIcon(schedule['event'] ?? ''),
                  color: isCompleted
                      ? theme.colorScheme.primary
                      : theme.colorScheme.secondary,
                  size: 20,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: theme.colorScheme.outline.withOpacity(0.2),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          // 内容
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                top: 8,
                bottom: isLast ? 16 : 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    schedule['time'] ?? '',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    schedule['event'] ?? '',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: isCompleted
                          ? theme.colorScheme.onSurface.withOpacity(0.5)
                          : theme.colorScheme.onSurface,
                      decoration: isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}