import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'health_data.dart';

class LocalStore {
  static SharedPreferences? _prefs;

  static const _kFamilyPhone = 'family_phone';
  static const _kFamilyLoggedIn = 'family_logged_in';
  static const _kPatientCode = 'patient_code';
  static const _kBindCode = 'bind_code';
  static const _kBoundPatientCode = 'bound_patient_code';
  static const _kBoundPatientByAccount = 'bound_patient_by_account';
  static const _kApiUrl = 'api_url';
  static const _kDevMode = 'dev_mode';

  static const _kFixedPatientCode = 'PAT-TEST-001';
  static const _kFixedBindCode = 'BIND-TEST-20260103';
  
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
    // 测试场景使用固定编码，便于调试与分享
    _prefs!.setString(_kPatientCode, _kFixedPatientCode);
    _prefs!.setString(_kBindCode, _kFixedBindCode);

    // 初始化按账号存储的绑定映射
    if (!_prefs!.containsKey(_kBoundPatientByAccount)) {
      _prefs!.setString(_kBoundPatientByAccount, jsonEncode(<String, String>{}));
    }
  }

  static String _generatePatientCode() {
    return _kFixedPatientCode;
  }

  static String _generateBindCode() {
    return _kFixedBindCode;
  }

  static String get patientCode => _prefs?.getString(_kPatientCode) ?? 'PAT-000000';
  static String get bindCode => _prefs?.getString(_kBindCode) ?? '000000';
  static String? get boundPatientCode => _prefs?.getString(_kBoundPatientCode);

  // 账户级绑定信息
  static Map<String, String> _getBoundMap() {
    if (_prefs == null) return {};
    final raw = _prefs!.getString(_kBoundPatientByAccount);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
    } catch (_) {}
    return {};
  }

  static Future<void> _saveBoundMap(Map<String, String> map) async {
    if (_prefs == null) return;
    await _prefs!.setString(_kBoundPatientByAccount, jsonEncode(map));
  }

  static String? getBoundPatientForAccount(String? phone) {
    if (phone == null || phone.isEmpty) return null;
    final map = _getBoundMap();
    return map[phone];
  }

  static Future<void> regenerateBindCode() async {
    if (_prefs == null) return;
    _prefs!.setString(_kBindCode, _generateBindCode());
  }

  static Future<void> setBoundPatient(String code) async {
    if (_prefs == null) return;
    await _prefs!.setString(_kBoundPatientCode, code);
  }

  static Future<void> setBoundPatientForAccount({required String phone, required String code}) async {
    if (_prefs == null) return;
    final map = _getBoundMap();
    map[phone] = code;
    await _saveBoundMap(map);
    await _prefs!.setString(_kBoundPatientCode, code);
  }

  static Future<void> clearBinding() async {
    if (_prefs == null) return;
    await _prefs!.remove(_kBoundPatientCode);
    if (familyPhone != null) {
      final map = _getBoundMap();
      map.remove(familyPhone!);
      await _saveBoundMap(map);
    }
  }

  // Auth session（仅本地会话状态）
  static Future<void> saveSession(String phone) async {
    if (_prefs == null) return;
    await _prefs!.setString(_kFamilyPhone, phone);
    await _prefs!.setBool(_kFamilyLoggedIn, true);
  }

  static Future<void> logout() async {
    if (_prefs == null) return;
    await _prefs!.setBool(_kFamilyLoggedIn, false);
    await _prefs!.remove(_kFamilyPhone);
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

  static String get apiUrl => _prefs?.getString(_kApiUrl) ?? 'http://127.0.0.1:5000';
  static set apiUrl(String value) => _prefs?.setString(_kApiUrl, value);

  static bool get devMode => _prefs?.getBool(_kDevMode) ?? false;
  static set devMode(bool value) => _prefs?.setBool(_kDevMode, value);
}
