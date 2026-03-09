import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service for communicating with the Kawabel backend.
/// Handles progress tracking, assignments, and student registration.
class ApiService {
  static const _baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:3001',
  );

  /// Register or update a student on the server
  static Future<void> registerStudent({
    required String name,
    required String grade,
    String? phone,
    String? parentPhone,
    String? parentName,
  }) async {
    try {
      await http.post(
        Uri.parse('$_baseUrl/api/students'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'grade': grade,
          'phone': phone ?? '',
          'parent_phone': parentPhone ?? '',
          'parent_name': parentName ?? '',
        }),
      );
    } catch (_) {
      // Silently fail — app works offline too
    }
  }

  /// Save a learning session's progress
  static Future<void> saveProgress({
    required String studentId,
    required String subject,
    required String topic,
    required int score,
    required int total,
    required String type, // 'homework', 'test', 'dictation'
  }) async {
    try {
      await http.post(
        Uri.parse('$_baseUrl/api/progress'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'student_id': studentId,
          'subject': subject,
          'topic': topic,
          'score': score,
          'total': total,
          'type': type,
        }),
      );
    } catch (_) {
      // Silently fail
    }
  }

  /// Get upcoming assignments for a student's grade
  static Future<List<Map<String, dynamic>>> getAssignments({
    String? grade,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/assignments')
          .replace(queryParameters: grade != null ? {'grade': grade} : null);
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['assignments'] ?? []);
      }
    } catch (_) {}
    return [];
  }

  /// Get student's progress history
  static Future<List<Map<String, dynamic>>> getProgress({
    required String studentId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/students/$studentId/progress'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['progress'] ?? []);
      }
    } catch (_) {}
    return [];
  }

  /// Get available question bank topics for a subject and grade
  static Future<Map<String, dynamic>> getQuestionBank({
    required String subject,
    required String grade,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/questions')
            .replace(queryParameters: {'subject': subject, 'grade': grade}),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (_) {}
    return {};
  }
}
