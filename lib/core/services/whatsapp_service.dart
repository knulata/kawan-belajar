import 'dart:convert';
import 'package:http/http.dart' as http;

class WhatsAppService {
  static const _apiBaseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:3001',
  );

  /// Send a WhatsApp alert to a parent about an upcoming event
  static Future<bool> sendAlert({
    required String parentPhone,
    required String parentName,
    required String studentName,
    required String alertType, // 'homework', 'test', 'daily_report', 'streak'
    required String message,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/api/whatsapp/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': parentPhone,
          'parent_name': parentName,
          'student_name': studentName,
          'alert_type': alertType,
          'message': message,
        }),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Schedule a reminder alert for homework/test
  static Future<bool> scheduleReminder({
    required String parentPhone,
    required String parentName,
    required String studentName,
    required String title,
    required String subject,
    required DateTime dueDate,
    required String type, // 'homework' or 'test'
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/api/whatsapp/schedule'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': parentPhone,
          'parent_name': parentName,
          'student_name': studentName,
          'title': title,
          'subject': subject,
          'due_date': dueDate.toIso8601String(),
          'type': type,
        }),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Send daily study summary to parent
  static Future<bool> sendDailySummary({
    required String parentPhone,
    required String parentName,
    required String studentName,
    required int minutesStudied,
    required int starsEarned,
    required List<String> subjectsStudied,
    required int streakDays,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/api/whatsapp/daily-summary'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': parentPhone,
          'parent_name': parentName,
          'student_name': studentName,
          'minutes_studied': minutesStudied,
          'stars_earned': starsEarned,
          'subjects_studied': subjectsStudied,
          'streak_days': streakDays,
        }),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Format phone number to international format (Indonesia)
  static String formatPhoneNumber(String phone) {
    phone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (phone.startsWith('08')) {
      phone = '62${phone.substring(1)}';
    } else if (phone.startsWith('8')) {
      phone = '62$phone';
    } else if (phone.startsWith('+62')) {
      phone = phone.substring(1);
    }
    return phone;
  }
}
