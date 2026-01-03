import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStore {
  static SharedPreferences? _prefs;

  static const _kFamilyPhone = 'family_phone';
  static const _kFamilyPassword = 'family_password';
  static const _kFamilyLoggedIn = 'family_logged_in';
  static const _kPatientCode = 'patient_code';
  static const _kBindCode = 'bind_code';
  static const _kBoundPatientCode = 'bound_patient_code';

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
}
