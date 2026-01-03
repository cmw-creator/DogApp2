import 'dart:math';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'health_data.dart';

class LocalStore {
  static SharedPreferences? _prefs;

  static const _kFamilyPhone = 'family_phone';
  static const _kFamilyPassword = 'family_password';
  static const _kFamilyLoggedIn = 'family_logged_in';
  static const _kPatientCode = 'patient_code';
  static const _kBindCode = 'bind_code';
  static const _kBoundPatientCode = 'bound_patient_code';
  
  // 健康数据
  static const _kHealthMetrics = 'health_metrics'; // JSON列表
  static const _kMedicines = 'medicines'; // JSON列表
  static const _kMedicineIntakes = 'medicine_intakes'; // JSON列表

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    _ensureCodes();
  }

  static void _ensureCodes() {
    if (_prefs == null) return;
    if (!_prefs!.containsKey(_kPatientCode)) {
      _prefs!.setString(_kPatientCode, _generatePatientCode());
    }
    if (!_prefs!.containsKey(_kBindCode)) {
      _prefs!.setString(_kBindCode, _generateBindCode());
    }
  }

  static String _generatePatientCode() {
    final rand = Random();
    final number = rand.nextInt(900000) + 100000; // 6 digits
    return 'PAT-$number';
  }

  static String _generateBindCode() {
    final rand = Random();
    final number = rand.nextInt(900000) + 100000; // 6 digits
    return number.toString();
  }

  static String get patientCode => _prefs?.getString(_kPatientCode) ?? 'PAT-000000';
  static String get bindCode => _prefs?.getString(_kBindCode) ?? '000000';
  static String? get boundPatientCode => _prefs?.getString(_kBoundPatientCode);

  static Future<void> regenerateBindCode() async {
    if (_prefs == null) return;
    _prefs!.setString(_kBindCode, _generateBindCode());
  }

  static Future<void> setBoundPatient(String code) async {
    if (_prefs == null) return;
    await _prefs!.setString(_kBoundPatientCode, code);
  }

  static Future<void> clearBinding() async {
    if (_prefs == null) return;
    await _prefs!.remove(_kBoundPatientCode);
  }

  // Auth
  static Future<bool> register(String phone, String password) async {
    if (_prefs == null) return false;
    await _prefs!.setString(_kFamilyPhone, phone);
    await _prefs!.setString(_kFamilyPassword, password);
    await _prefs!.setBool(_kFamilyLoggedIn, true);
    return true;
  }

  static Future<bool> login(String phone, String password) async {
    if (_prefs == null) return false;
    final savedPhone = _prefs!.getString(_kFamilyPhone);
    final savedPwd = _prefs!.getString(_kFamilyPassword);
    final ok = savedPhone == phone && savedPwd == password;
    if (ok) await _prefs!.setBool(_kFamilyLoggedIn, true);
    return ok;
  }

  static Future<void> logout() async {
    if (_prefs == null) return;
    await _prefs!.setBool(_kFamilyLoggedIn, false);
  }

  static bool get isLoggedIn => _prefs?.getBool(_kFamilyLoggedIn) ?? false;
  static String? get familyPhone => _prefs?.getString(_kFamilyPhone);

  static Future<void> ensureInit() async {
    if (_prefs == null) {
      await init();
    }
  }

  // ===== 健康数据管理 =====
  
  static Future<void> recordHealthMetrics(HealthMetrics metrics) async {
    if (_prefs == null) return;
    final list = getHealthMetrics();
    list.add(metrics);
    final jsonList = list.map((m) => jsonEncode(m.toJson())).toList();
    await _prefs!.setStringList(_kHealthMetrics, jsonList);
  }

  static List<HealthMetrics> getHealthMetrics({int days = 30}) {
    if (_prefs == null) return [];
    final jsonList = _prefs!.getStringList(_kHealthMetrics) ?? [];
    final now = DateTime.now();
    final cutoff = now.subtract(Duration(days: days));
    
    return jsonList
        .map((json) => HealthMetrics.fromJson(jsonDecode(json) as Map<String, dynamic>))
        .where((m) => m.timestamp.isAfter(cutoff))
        .toList();
  }

  static HealthMetrics? getTodayHealthMetrics() {
    final metrics = getHealthMetrics();
    final today = DateTime.now();
    try {
      return metrics.lastWhere(
        (m) => m.timestamp.year == today.year &&
            m.timestamp.month == today.month &&
            m.timestamp.day == today.day,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> addMedicine(Medicine medicine) async {
    if (_prefs == null) return;
    final list = getMedicines();
    list.removeWhere((m) => m.id == medicine.id); // 防重复
    list.add(medicine);
    final jsonList = list.map((m) => jsonEncode(m.toJson())).toList();
    await _prefs!.setStringList(_kMedicines, jsonList);
  }

  static List<Medicine> getMedicines() {
    if (_prefs == null) return [];
    final jsonList = _prefs!.getStringList(_kMedicines) ?? [];
    return jsonList
        .map((json) => Medicine.fromJson(jsonDecode(json) as Map<String, dynamic>))
        .toList();
  }

  static Future<void> recordMedicineIntake(MedicineIntake intake) async {
    if (_prefs == null) return;
    final list = getMedicineIntakes();
    list.add(intake);
    final jsonList = list.map((m) => jsonEncode(m.toJson())).toList();
    await _prefs!.setStringList(_kMedicineIntakes, jsonList);
  }

  static List<MedicineIntake> getMedicineIntakes({int days = 7}) {
    if (_prefs == null) return [];
    final jsonList = _prefs!.getStringList(_kMedicineIntakes) ?? [];
    final now = DateTime.now();
    final cutoff = now.subtract(Duration(days: days));
    
    return jsonList
        .map((json) => MedicineIntake.fromJson(jsonDecode(json) as Map<String, dynamic>))
        .where((m) => m.date.isAfter(cutoff))
        .toList();
  }

  static List<MedicineIntake> getTodayMedicineIntakes() {
    final intakes = getMedicineIntakes();
    final today = DateTime.now();
    return intakes
        .where((m) => m.date.year == today.year &&
            m.date.month == today.month &&
            m.date.day == today.day)
        .toList();
  }

  static Future<void> markMedicineTaken(String medicineId, String time) async {
    if (_prefs == null) return;
    final intakes = getMedicineIntakes();
    final today = DateTime.now();
    
    // 找到今天该药该时间的记录
    var intake = intakes.firstWhere(
      (m) => m.medicineId == medicineId &&
          m.time == time &&
          m.date.year == today.year &&
          m.date.month == today.month &&
          m.date.day == today.day,
      orElse: () => MedicineIntake(
        medicineId: medicineId,
        date: today,
        time: time,
        taken: true,
      ),
    );
    
    if (!intakes.contains(intake)) {
      intakes.add(intake);
    } else {
      intake.taken = true;
    }
    
    final jsonList = intakes.map((m) => jsonEncode(m.toJson())).toList();
    await _prefs!.setStringList(_kMedicineIntakes, jsonList);
  }

  static int getMedicineAdherenceRate() {
    final intakes = getMedicineIntakes(days: 7);
    if (intakes.isEmpty) return 0;
    final taken = intakes.where((m) => m.taken).length;
    return ((taken / intakes.length) * 100).toInt();
  }
}
