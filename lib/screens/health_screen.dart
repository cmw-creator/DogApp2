import 'package:flutter/material.dart';
import '../services/local_store.dart';
import '../services/health_data.dart';

class HealthScreen extends StatefulWidget {
  const HealthScreen({Key? key}) : super(key: key);

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  HealthMetrics? _todayMetrics;
  List<Medicine> _medicines = [];
  List<MedicineIntake> _todayIntakes = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadHealthData();
  }

  Future<void> _loadHealthData() async {
    setState(() => _loading = true);
    try {
      await LocalStore.ensureInit();
      _todayMetrics = LocalStore.getTodayHealthMetrics();
      _medicines = LocalStore.getMedicines();
      _todayIntakes = LocalStore.getTodayMedicineIntakes();
    } finally {
      setState(() => _loading = false);
    }
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
                heartRate:
                    heartRateCtl.text.isEmpty ? null : int.tryParse(heartRateCtl.text),
                bloodPressure: bp,
                temperature: tempCtl.text.isEmpty ? null : double.tryParse(tempCtl.text),
                steps: stepsCtl.text.isEmpty ? null : int.tryParse(stepsCtl.text),
                sleepDuration: sleepCtl.text.isEmpty ? null : int.tryParse(sleepCtl.text),
              );
              await LocalStore.recordHealthMetrics(metrics);
              if (mounted) {
                Navigator.pop(ctx);
                _loadHealthData();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadHealthData(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 顶部健康状态卡片
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.teal.shade50, Colors.teal.shade100],
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
                        size: 40,
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
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _todayMetrics != null ? '已记录' : '未记录',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: _todayMetrics != null
                                  ? Colors.green.shade700
                                  : Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
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
            const SizedBox(height: 16),

            // 今日数据卡片
            if (_todayMetrics != null) ...[
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
                        _buildMetricRow('🩸 血压', _todayMetrics!.bloodPressure!, Colors.blue),
                        const SizedBox(height: 8),
                      ],
                      if (_todayMetrics!.temperature != null) ...[
                        _buildMetricRow(
                          '🌡️ 温度',
                          '${_todayMetrics!.temperature}°C',
                          Colors.orange,
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

            // 用药提醒卡片
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                            Icon(Icons.medication, color: Colors.purple.shade700),
                            const SizedBox(width: 8),
                            Text(
                              '今日用药',
                              style:
                                  theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_todayIntakes.where((m) => m.taken).length}/${_todayIntakes.length}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.purple.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_todayIntakes.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          '今天暂无用药计划',
                          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      ..._todayIntakes.map(
                        (intake) {
                          final medicine =
                              _medicines.firstWhere((m) => m.id == intake.medicineId);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: intake.taken
                                    ? Colors.green.shade50
                                    : Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: intake.taken
                                      ? Colors.green.shade300
                                      : Colors.orange.shade300,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    intake.taken
                                        ? Icons.check_circle
                                        : Icons.schedule,
                                    color: intake.taken
                                        ? Colors.green.shade700
                                        : Colors.orange.shade700,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${medicine.name} ${medicine.dosage}',
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(fontWeight: FontWeight.w500),
                                        ),
                                        Text(
                                          intake.time,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(color: Colors.grey.shade600),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!intake.taken)
                                    ElevatedButton(
                                      onPressed: () async {
                                        await LocalStore.markMedicineTaken(
                                          intake.medicineId,
                                          intake.time,
                                        );
                                        _loadHealthData();
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green.shade700,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                      ),
                                      child: const Text('已服用', style: TextStyle(fontSize: 12)),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
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
}
