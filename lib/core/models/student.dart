import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Student {
  final String name;
  final String grade;
  final int stars;
  final int level;

  Student({
    required this.name,
    required this.grade,
    this.stars = 0,
    this.level = 1,
  });
}

class StudentProvider extends ChangeNotifier {
  Student? _student;
  String _apiKey = '';

  Student? get student => _student;
  bool get isLoggedIn => _student != null;
  String get apiKey => _apiKey;

  Future<void> login(String name, String grade, String apiKey) async {
    _student = Student(name: name, grade: grade);
    _apiKey = apiKey;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('student_name', name);
    await prefs.setString('student_grade', grade);
    await prefs.setString('api_key', apiKey);
    notifyListeners();
  }

  Future<void> loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('student_name');
    final grade = prefs.getString('student_grade');
    final apiKey = prefs.getString('api_key');
    if (name != null && grade != null && apiKey != null) {
      _student = Student(name: name, grade: grade);
      _apiKey = apiKey;
      notifyListeners();
    }
  }

  void addStars(int count) {
    if (_student != null) {
      _student = Student(
        name: _student!.name,
        grade: _student!.grade,
        stars: _student!.stars + count,
        level: _student!.level,
      );
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _student = null;
    _apiKey = '';
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    notifyListeners();
  }
}
