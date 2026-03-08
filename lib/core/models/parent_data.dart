import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StudySession {
  final String subject;
  final DateTime date;
  final int durationMinutes;
  final int starsEarned;
  final String type; // 'chat', 'dictation', 'test_prep'
  final int? testScore;
  final int? testTotal;

  StudySession({
    required this.subject,
    required this.date,
    required this.durationMinutes,
    required this.starsEarned,
    required this.type,
    this.testScore,
    this.testTotal,
  });

  Map<String, dynamic> toJson() => {
        'subject': subject,
        'date': date.toIso8601String(),
        'durationMinutes': durationMinutes,
        'starsEarned': starsEarned,
        'type': type,
        'testScore': testScore,
        'testTotal': testTotal,
      };

  factory StudySession.fromJson(Map<String, dynamic> json) => StudySession(
        subject: json['subject'] ?? '',
        date: DateTime.parse(json['date']),
        durationMinutes: json['durationMinutes'] ?? 0,
        starsEarned: json['starsEarned'] ?? 0,
        type: json['type'] ?? 'chat',
        testScore: json['testScore'],
        testTotal: json['testTotal'],
      );
}

class ScheduledReminder {
  final String id;
  final String title;
  final String subject;
  final DateTime dueDate;
  final String type; // 'homework', 'test'
  final bool whatsappEnabled;

  ScheduledReminder({
    required this.id,
    required this.title,
    required this.subject,
    required this.dueDate,
    required this.type,
    this.whatsappEnabled = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subject': subject,
        'dueDate': dueDate.toIso8601String(),
        'type': type,
        'whatsappEnabled': whatsappEnabled,
      };

  factory ScheduledReminder.fromJson(Map<String, dynamic> json) =>
      ScheduledReminder(
        id: json['id'] ?? '',
        title: json['title'] ?? '',
        subject: json['subject'] ?? '',
        dueDate: DateTime.parse(json['dueDate']),
        type: json['type'] ?? 'homework',
        whatsappEnabled: json['whatsappEnabled'] ?? true,
      );
}

class ParentDataProvider extends ChangeNotifier {
  String? _parentPhone;
  String? _parentName;
  bool _whatsappAlertsEnabled = false;
  List<StudySession> _sessions = [];
  List<ScheduledReminder> _reminders = [];

  String? get parentPhone => _parentPhone;
  String? get parentName => _parentName;
  bool get whatsappAlertsEnabled => _whatsappAlertsEnabled;
  bool get isParentLinked => _parentPhone != null && _parentPhone!.isNotEmpty;
  List<StudySession> get sessions => List.unmodifiable(_sessions);
  List<ScheduledReminder> get reminders => List.unmodifiable(_reminders);

  // Study stats
  int get totalSessions => _sessions.length;
  int get totalMinutes =>
      _sessions.fold(0, (sum, s) => sum + s.durationMinutes);
  int get totalStars => _sessions.fold(0, (sum, s) => sum + s.starsEarned);
  double get averageTestScore {
    final tests = _sessions.where((s) => s.testScore != null).toList();
    if (tests.isEmpty) return 0;
    return tests.fold(0.0,
            (sum, s) => sum + (s.testScore! / s.testTotal! * 100)) /
        tests.length;
  }

  List<StudySession> get todaySessions {
    final now = DateTime.now();
    return _sessions
        .where((s) =>
            s.date.year == now.year &&
            s.date.month == now.month &&
            s.date.day == now.day)
        .toList();
  }

  List<StudySession> get thisWeekSessions {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    return _sessions.where((s) => s.date.isAfter(weekAgo)).toList();
  }

  Map<String, int> get subjectBreakdown {
    final map = <String, int>{};
    for (final s in _sessions) {
      map[s.subject] = (map[s.subject] ?? 0) + s.durationMinutes;
    }
    return map;
  }

  int get streakDays {
    if (_sessions.isEmpty) return 0;
    final sorted = List<StudySession>.from(_sessions)
      ..sort((a, b) => b.date.compareTo(a.date));
    int streak = 1;
    DateTime lastDate = DateTime(
        sorted.first.date.year, sorted.first.date.month, sorted.first.date.day);
    final today = DateTime(
        DateTime.now().year, DateTime.now().month, DateTime.now().day);
    if (lastDate.isBefore(today.subtract(const Duration(days: 1)))) return 0;
    for (int i = 1; i < sorted.length; i++) {
      final date = DateTime(
          sorted[i].date.year, sorted[i].date.month, sorted[i].date.day);
      if (lastDate.difference(date).inDays == 1) {
        streak++;
        lastDate = date;
      } else if (lastDate.difference(date).inDays > 1) {
        break;
      }
    }
    return streak;
  }

  List<ScheduledReminder> get upcomingReminders {
    final now = DateTime.now();
    return _reminders
        .where((r) => r.dueDate.isAfter(now))
        .toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _parentPhone = prefs.getString('parent_phone');
    _parentName = prefs.getString('parent_name');
    _whatsappAlertsEnabled = prefs.getBool('whatsapp_alerts') ?? false;

    final sessionsJson = prefs.getString('study_sessions');
    if (sessionsJson != null) {
      final list = jsonDecode(sessionsJson) as List;
      _sessions =
          list.map((e) => StudySession.fromJson(e as Map<String, dynamic>)).toList();
    }

    final remindersJson = prefs.getString('reminders');
    if (remindersJson != null) {
      final list = jsonDecode(remindersJson) as List;
      _reminders = list
          .map((e) => ScheduledReminder.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    notifyListeners();
  }

  Future<void> setParentInfo({
    required String phone,
    required String name,
  }) async {
    _parentPhone = phone;
    _parentName = name;
    _whatsappAlertsEnabled = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('parent_phone', phone);
    await prefs.setString('parent_name', name);
    await prefs.setBool('whatsapp_alerts', true);
    notifyListeners();
  }

  Future<void> toggleWhatsappAlerts(bool enabled) async {
    _whatsappAlertsEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('whatsapp_alerts', enabled);
    notifyListeners();
  }

  Future<void> addSession(StudySession session) async {
    _sessions.add(session);
    await _saveSessions();
    notifyListeners();
  }

  Future<void> addReminder(ScheduledReminder reminder) async {
    _reminders.add(reminder);
    await _saveReminders();
    notifyListeners();
  }

  Future<void> removeReminder(String id) async {
    _reminders.removeWhere((r) => r.id == id);
    await _saveReminders();
    notifyListeners();
  }

  Future<void> removeParent() async {
    _parentPhone = null;
    _parentName = null;
    _whatsappAlertsEnabled = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('parent_phone');
    await prefs.remove('parent_name');
    await prefs.setBool('whatsapp_alerts', false);
    notifyListeners();
  }

  Future<void> _saveSessions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'study_sessions',
      jsonEncode(_sessions.map((s) => s.toJson()).toList()),
    );
  }

  Future<void> _saveReminders() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'reminders',
      jsonEncode(_reminders.map((r) => r.toJson()).toList()),
    );
  }
}
