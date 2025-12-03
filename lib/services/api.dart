import 'dart:convert';
import 'package:http/http.dart' as http;

class Api {
  // 默认服务器地址（dog_server.py 监听 5000 端口）
  static String serverUrl = 'http://127.0.0.1:5000';

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
      };

  // 获取机器狗状态：GET /status
  static Future<Map<String, dynamic>?> getStatus() async {
    try {
      final resp = await http
          .get(Uri.parse('$serverUrl/status'))
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        return json.decode(resp.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  // 发送指令：POST /send_command
  static Future<bool> sendCommand(String command) async {
    try {
      final body = json.encode(
          {'command': command, 'timestamp': DateTime.now().toIso8601String()});
      final resp = await http
          .post(Uri.parse('$serverUrl/send_command'),
              headers: _headers, body: body)
          .timeout(const Duration(seconds: 5));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // 返回充电：POST /return_home
  static Future<bool> returnHome() async {
    try {
      final resp = await http
          .post(Uri.parse('$serverUrl/return_home'), headers: _headers)
          .timeout(const Duration(seconds: 8));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // 获取家庭信息：GET /get_family_info
  static Future<Map<String, dynamic>?> getFamilyInfo() async {
    try {
      final resp = await http
          .get(Uri.parse('$serverUrl/get_family_info'))
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        return json.decode(resp.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  // 发送 SOS：POST /sos_alert
  static Future<bool> sendSos(Map<String, dynamic> sosData) async {
    try {
      final resp = await http
          .post(Uri.parse('$serverUrl/sos_alert'),
              headers: _headers, body: json.encode(sosData))
          .timeout(const Duration(seconds: 5));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // 获取人脸列表：GET /get_face_info
  static Future<Map<String, dynamic>?> getFaceInfo() async {
    try {
      final resp = await http
          .get(Uri.parse('$serverUrl/get_face_info'))
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        return json.decode(resp.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  // 更新/新增人脸信息：POST /update_face_info
  static Future<bool> updateFaceInfo(Map<String, dynamic> payload) async {
    try {
      final resp = await http
          .post(Uri.parse('$serverUrl/update_face_info'),
              headers: _headers, body: json.encode(payload))
          .timeout(const Duration(seconds: 5));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // 获取记忆库问答列表：GET /get_family_questions
  static Future<List<dynamic>?> getFamilyQuestions() async {
    try {
      final resp = await http
          .get(Uri.parse('$serverUrl/get_family_questions'))
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        return json.decode(resp.body) as List<dynamic>;
      }
    } catch (_) {}
    return null;
  }

  // 更新/新增问答：POST /update_family_question
  static Future<bool> updateFamilyQuestion(Map<String, dynamic> payload) async {
    try {
      final resp = await http
          .post(Uri.parse('$serverUrl/update_family_question'),
              headers: _headers, body: json.encode(payload))
          .timeout(const Duration(seconds: 5));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // 删除问答：POST /delete_family_question
  static Future<bool> deleteFamilyQuestion(int questionId) async {
    try {
      final resp = await http
          .post(Uri.parse('$serverUrl/delete_family_question'),
              headers: _headers,
              body: json.encode({'question_id': questionId}))
          .timeout(const Duration(seconds: 5));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // 获取药品信息：GET /get_qr_code_info
  static Future<Map<String, dynamic>?> getMedicineInfo() async {
    try {
      final resp = await http
          .get(Uri.parse('$serverUrl/get_qr_code_info'))
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        return json.decode(resp.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  // 更新/新增药品：POST /update_qr_code_info
  static Future<bool> updateMedicine(Map<String, dynamic> payload) async {
    try {
      final resp = await http
          .post(Uri.parse('$serverUrl/update_qr_code_info'),
              headers: _headers, body: json.encode(payload))
          .timeout(const Duration(seconds: 5));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // 删除药品：POST /delete_qr_code_info
  static Future<bool> deleteMedicine(String medId) async {
    try {
      final resp = await http
          .post(Uri.parse('$serverUrl/delete_qr_code_info'),
              headers: _headers, body: json.encode({'med_id': medId}))
          .timeout(const Duration(seconds: 5));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // GPS 上传：POST /upload_gps
  static Future<bool> uploadGps(Map<String, dynamic> gpsData) async {
    try {
      final resp = await http
          .post(Uri.parse('$serverUrl/upload_gps'),
              headers: _headers, body: json.encode(gpsData))
          .timeout(const Duration(seconds: 5));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // 获取 GPS 历史：GET /get_gps_history
  static Future<List<dynamic>?> getGpsHistory() async {
    try {
      final resp = await http
          .get(Uri.parse('$serverUrl/get_gps_history'))
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        return json.decode(resp.body) as List<dynamic>;
      }
    } catch (_) {}
    return null;
  }

  // 获取日程列表
  static Future<List<dynamic>?> getSchedules() async {
    try {
      final resp = await http
          .get(Uri.parse('$serverUrl/get_schedule'))
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        return json.decode(resp.body) as List<dynamic>;
      }
    } catch (_) {}
    return null;
  }

  // 新增/更新日程
  static Future<bool> upsertSchedule(Map<String, dynamic> payload) async {
    try {
      final resp = await http
          .post(Uri.parse('$serverUrl/update_schedule'),
              headers: _headers, body: json.encode(payload))
          .timeout(const Duration(seconds: 5));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // 删除日程
  static Future<bool> deleteSchedule(int scheduleId) async {
    try {
      final resp = await http
          .post(Uri.parse('$serverUrl/delete_schedule'),
              headers: _headers,
              body: json.encode({'schedule_id': scheduleId}))
          .timeout(const Duration(seconds: 5));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // 获取重要提醒：GET /get_important_message
  static Future<Map<String, dynamic>?> getImportantMessage() async {
    try {
      final resp = await http
          .get(Uri.parse('$serverUrl/get_important_message'))
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        // 后端用 has_message 字段指示是否有有效提醒
        if (data['has_message'] == true) {
          return data;
        }
      }
    } catch (_) {}
    return null;
  }
}
