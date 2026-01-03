import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/api.dart';
import '../services/local_store.dart';
import '../services/health_data.dart';
import '../services/in_app_notification.dart';
import '../services/notification_service.dart';
import 'notification_screen.dart';

// 今天页：日期、天气、日程、用药
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
  final List<Map<String, dynamic>> _schedules = [];
  Timer? _reminderTimer;
  final Map<int, String> _reminderFired = {};
  StreamSubscription<Map<String, dynamic>>? _notifSub;
  String? _importantMessage;
  String? _importantMessageType;
  HealthMetrics? _todayMetrics;
  List<MedicineIntake> _medicineIntakes = [];

  @override
  void initState() {
    super.initState();
    _updateDate();
    _loadWeather();
    _loadSchedules();
    _loadImportantMessage();
    _loadDayData();
    _startNotificationListener();
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

  Future<void> _loadSchedules() async {
    final data = await Api.getSchedules();
    if (!mounted) return;
    setState(() {
      _schedules
        ..clear()
        ..addAll((data ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList());
    });
    _restartReminderMonitor();
  }

  Future<void> _loadDayData() async {
    await LocalStore.ensureInit();
    final intakes = LocalStore.getTodayMedicineIntakes();
    final metrics = LocalStore.getTodayHealthMetrics();
    if (!mounted) return;
    setState(() {
      _medicineIntakes = intakes;
      _todayMetrics = metrics;
    });
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

  DateTime? _parseScheduleTime(String timeStr) {
    if (timeStr.isEmpty) return null;
    final parts = timeStr.split(':');
    if (parts.length < 2) return null;
    final now = DateTime.now();
    try {
      final hh = int.parse(parts[0]);
      final mm = int.parse(parts[1].split(' ').first);
      return DateTime(now.year, now.month, now.day, hh, mm);
    } catch (_) {
      return null;
    }
  }

  void _restartReminderMonitor() {
    _reminderTimer?.cancel();
    _checkDueSchedules(force: true);
    _reminderTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkDueSchedules();
    });
  }

  void _checkDueSchedules({bool force = false}) {
    final now = DateTime.now();
    final todayKey = '${now.year}-${now.month}-${now.day}';
    for (final schedule in _schedules) {
      final id = schedule['id'] is int
          ? schedule['id'] as int
          : schedule.hashCode;
      final timeStr = (schedule['time'] ?? '').toString();
      final event = (schedule['event'] ?? '').toString();
      final dt = _parseScheduleTime(timeStr);
      if (dt == null) continue;

      if (!force && _reminderFired[id] == todayKey) continue;

      if (now.isAfter(dt) && now.difference(dt).inMinutes <= 1) {
        _reminderFired[id] = todayKey;
        _showScheduleReminder(event: event, timeStr: timeStr);
      }
    }
  }

  void _showScheduleReminder({required String event, required String timeStr}) {
    final title = '日程提醒';
    final body = '$event ($timeStr)';
    InAppNotification.instance.show(
      title: title,
      message: body,
      severity: InAppNotificationSeverity.info,
      actionLabel: '查看通知',
      onAction: () {
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NotificationCenterScreen()),
        );
      },
    );
  }

  void _startNotificationListener() {
    NotificationService.instance.start();
    _notifSub = NotificationService.instance.stream.listen((event) {
      final type = event['type'];
      if (type == 'schedule') {
        final payload = event['payload'] as Map<String, dynamic>?;
        final timeStr = payload?['time']?.toString() ?? '';
        final msg = event['message']?.toString() ?? '日程提醒';
        _showScheduleReminder(
          event: payload?['event']?.toString() ?? msg,
          timeStr: timeStr,
        );
      } else if (type == 'sos') {
        final msg = event['message']?.toString() ?? 'SOS 求助';
        _showNotificationDialog(title: 'SOS', message: msg);
      } else {
        final msg = event['message']?.toString() ?? '收到通知';
        _showNotificationDialog(title: '通知', message: msg);
      }
    });
  }

  void _showNotificationDialog({required String title, required String message}) {
    InAppNotification.instance.show(
      title: title,
      message: message,
      severity:
          title == 'SOS' ? InAppNotificationSeverity.danger : InAppNotificationSeverity.info,
      actionLabel: '查看通知',
      onAction: () {
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NotificationCenterScreen()),
        );
      },
    );
  }

  void _stopNotificationListener() {
    _notifSub?.cancel();
    NotificationService.instance.stop();
  }
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([_loadImportantMessage(), _loadDayData()]);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 顶部大卡片：日期+星期+天气
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200, width: 1),
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white,
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
                    const SizedBox(height: 16),
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.teal.shade50,
                              Colors.teal.shade100,
                            ],
                          ),
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.teal.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.favorite,
                                size: 36,
                                color: Colors.teal.shade700,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '今日健康',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.teal.shade900,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _todayMetrics != null ? '已记录' : '尚未记录',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: _todayMetrics != null
                                          ? Colors.green.shade700
                                          : Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: _showAddHealthDialog,
                              icon: const Icon(Icons.add),
                              label: const Text('记录'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_todayMetrics != null) ...[
                      const SizedBox(height: 16),
                      Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '今日数据',
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 12),
                              if (_todayMetrics!.heartRate != null) ...[
                                _buildMetricRow('❤️ 心率', '${_todayMetrics!.heartRate} bpm', Colors.red),
                                const SizedBox(height: 8),
                              ],
                              if (_todayMetrics!.bloodPressure != null) ...[
                                _buildMetricRow('🩸 血压', _todayMetrics!.bloodPressure!, Colors.orange),
                                const SizedBox(height: 8),
                              ],
                              if (_todayMetrics!.temperature != null) ...[
                                _buildMetricRow(
                                  '🌡️ 温度',
                                  '${_todayMetrics!.temperature}°C',
                                  Colors.orangeAccent,
                                ),
                                const SizedBox(height: 8),
                              ],
                              if (_todayMetrics!.steps != null) ...[
                                _buildMetricRow('👟 步数', '${_todayMetrics!.steps} 步', Colors.green),
                                const SizedBox(height: 8),
                              ],
                              if (_todayMetrics!.sleepDuration != null)
                                _buildMetricRow(
                                  '😴 睡眠',
                                  '${_todayMetrics!.sleepDuration} 分钟',
                                  Colors.indigo,
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // 重要提醒（更醒目）
            if (_importantMessage != null) ...[
              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.orange.shade300, width: 1.5),
                ),
                child: Padding(
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
            
            // 用药提醒卡片（如有）
            if (_medicineIntakes.isNotEmpty) ...[
              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.purple.shade300, width: 1.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.medication,
                              color: Colors.purple.shade700,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '今日用药提醒',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.purple.shade900,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade200,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_medicineIntakes.where((m) => m.taken).length}/${_medicineIntakes.length}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.purple.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ..._medicineIntakes.map(
                        (intake) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Icon(
                                intake.taken ? Icons.check_circle : Icons.schedule,
                                color: intake.taken ? Colors.green : Colors.orange,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                intake.time,
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  intake.taken ? '已服用' : '待服用',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color:
                                        intake.taken ? Colors.green : Colors.orange,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          ),
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
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200, width: 1),
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
                      final isCompleted = schedule['completed'] == true ||
                          schedule['completed'] == 'true';

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

  @override
  void dispose() {
    _reminderTimer?.cancel();
    _stopNotificationListener();
    super.dispose();
  }

  void _showAddHealthDialog() {
    final heartRateCtl = TextEditingController();
    final systolicCtl = TextEditingController();
    final diastolicCtl = TextEditingController();
    final tempCtl = TextEditingController();
    final stepsCtl = TextEditingController();
    final sleepCtl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('记录健康数据'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: heartRateCtl,
                decoration: const InputDecoration(labelText: '心率 (bpm)'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: systolicCtl,
                decoration: const InputDecoration(labelText: '收缩压'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: diastolicCtl,
                decoration: const InputDecoration(labelText: '舒张压'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: tempCtl,
                decoration: const InputDecoration(labelText: '温度 (°C)'),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
              TextField(
                controller: stepsCtl,
                decoration: const InputDecoration(labelText: '步数'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: sleepCtl,
                decoration: const InputDecoration(labelText: '睡眠时长 (分钟)'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              final bp = diastolicCtl.text.isEmpty || systolicCtl.text.isEmpty
                  ? null
                  : '${systolicCtl.text}/${diastolicCtl.text}';
              final metrics = HealthMetrics(
                timestamp: DateTime.now(),
                heartRate: heartRateCtl.text.isEmpty ? null : int.tryParse(heartRateCtl.text),
                bloodPressure: bp,
                temperature: tempCtl.text.isEmpty ? null : double.tryParse(tempCtl.text),
                steps: stepsCtl.text.isEmpty ? null : int.tryParse(stepsCtl.text),
                sleepDuration: sleepCtl.text.isEmpty ? null : int.tryParse(sleepCtl.text),
              );
              await LocalStore.recordHealthMetrics(metrics);
              if (mounted) {
                Navigator.pop(ctx);
                await _loadDayData();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('健康数据已记录')),
                );
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, Color color) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScheduleItem({
    required Map<String, dynamic> schedule,
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