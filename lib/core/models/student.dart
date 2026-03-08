import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Student {
  final String id;
  final String name;
  final String grade;
  final int stars;
  final int level;

  Student({
    required this.id,
    required this.name,
    required this.grade,
    this.stars = 0,
    this.level = 1,
  });
}

class StudentProvider extends ChangeNotifier {
  Student? _student;

  Student? get student => _student;
  bool get isLoggedIn => _student != null;

  Future<void> login(String name, String grade) async {
    final id = '${name.toLowerCase().replaceAll(' ', '_')}_${grade.replaceAll(' ', '')}';
    _student = Student(id: id, name: name, grade: grade);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('student_name', name);
    await prefs.setString('student_grade', grade);
    notifyListeners();
  }

  Future<void> loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('student_name');
    final grade = prefs.getString('student_grade');
    if (name != null && grade != null) {
      final id = '${name.toLowerCase().replaceAll(' ', '_')}_${grade.replaceAll(' ', '')}';
      _student = Student(id: id, name: name, grade: grade);

      // Load stars
      final stars = prefs.getInt('student_stars') ?? 0;
      _student = Student(id: id, name: name, grade: grade, stars: stars);
      notifyListeners();
    }
  }

  void addStars(int count) async {
    if (_student != null) {
      final newStars = _student!.stars + count;
      _student = Student(
        id: _student!.id,
        name: _student!.name,
        grade: _student!.grade,
        stars: newStars,
        level: (newStars ~/ 50) + 1,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('student_stars', newStars);
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _student = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('student_name');
    await prefs.remove('student_grade');
    notifyListeners();
  }
}
