// 健康数据模型与管理

class HealthMetrics {
  final DateTime timestamp;
  final int? heartRate; // 心率 bpm
  final String? bloodPressure; // 血压 "120/80"
  final double? temperature; // 温度 °C
  final int? bloodSugar; // 血糖 mg/dL
  final int? steps; // 步数
  final int? sleepDuration; // 睡眠时长 分钟

  HealthMetrics({
    required this.timestamp,
    this.heartRate,
    this.bloodPressure,
    this.temperature,
    this.bloodSugar,
    this.steps,
    this.sleepDuration,
  });

  // 转为JSON存储
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'heartRate': heartRate,
      'bloodPressure': bloodPressure,
      'temperature': temperature,
      'bloodSugar': bloodSugar,
      'steps': steps,
      'sleepDuration': sleepDuration,
    };
  }

  // 从JSON恢复
  factory HealthMetrics.fromJson(Map<String, dynamic> json) {
    return HealthMetrics(
      timestamp: DateTime.parse(json['timestamp'] as String),
      heartRate: json['heartRate'] as int?,
      bloodPressure: json['bloodPressure'] as String?,
      temperature: (json['temperature'] as num?)?.toDouble(),
      bloodSugar: json['bloodSugar'] as int?,
      steps: json['steps'] as int?,
      sleepDuration: json['sleepDuration'] as int?,
    );
  }
}

class Medicine {
  final String id;
  final String name;
  final String dosage; // 如 "1片" / "5ml"
  final List<String> times; // 服用时间 ["08:00", "14:00", "20:00"]
  final String? notes; // 备注

  Medicine({
    required this.id,
    required this.name,
    required this.dosage,
    required this.times,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'dosage': dosage,
      'times': times,
      'notes': notes,
    };
  }

  factory Medicine.fromJson(Map<String, dynamic> json) {
    return Medicine(
      id: json['id'] as String,
      name: json['name'] as String,
      dosage: json['dosage'] as String,
      times: List<String>.from(json['times'] as List),
      notes: json['notes'] as String?,
    );
  }
}

class MedicineIntake {
  final String medicineId;
  final DateTime date;
  final String time; // 计划服用时间 "08:00"
  bool taken; // 是否已服用
  final String? notes;

  MedicineIntake({
    required this.medicineId,
    required this.date,
    required this.time,
    this.taken = false,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'medicineId': medicineId,
      'date': date.toIso8601String(),
      'time': time,
      'taken': taken,
      'notes': notes,
    };
  }

  factory MedicineIntake.fromJson(Map<String, dynamic> json) {
    return MedicineIntake(
      medicineId: json['medicineId'] as String,
      date: DateTime.parse(json['date'] as String),
      time: json['time'] as String,
      taken: json['taken'] as bool? ?? false,
      notes: json['notes'] as String?,
    );
  }
}

// 健康数据统计汇总
class HealthSummary {
  final DateTime date;
  final int? avgHeartRate;
  final double? avgTemperature;
  final int totalSteps;
  final int sleepMinutes;
  final int medicineAdherence; // 用药遵从率 0-100

  HealthSummary({
    required this.date,
    this.avgHeartRate,
    this.avgTemperature,
    required this.totalSteps,
    required this.sleepMinutes,
    required this.medicineAdherence,
  });
}
