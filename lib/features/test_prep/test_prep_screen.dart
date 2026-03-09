import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/ai/chat_service.dart';
import '../../core/api/api_service.dart';
import '../../core/models/student.dart';
import '../../core/services/question_cache.dart';

class TestPrepScreen extends StatefulWidget {
  const TestPrepScreen({super.key});

  @override
  State<TestPrepScreen> createState() => _TestPrepScreenState();
}

class _TestPrepScreenState extends State<TestPrepScreen> {
  String _selectedSubject = 'Matematika';
  final _topicController = TextEditingController();
  bool _loading = false;
  List<Map<String, dynamic>> _questions = [];
  int _currentQuestion = 0;
  int? _selectedAnswer;
  bool _answered = false;
  int _score = 0;
  bool _showResults = false;

  final _subjects = [
    'Matematika',
    'Bahasa Indonesia',
    'Bahasa Mandarin',
    'IPA (Sains)',
    'IPS',
    'English',
    'PKN',
  ];


  Future<void> _generateTest() async {
    if (_topicController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tulis topik ujiannya dulu ya!')),
      );
      return;
    }

    setState(() => _loading = true);

    final student = context.read<StudentProvider>();
    final cache = QuestionCache();

    // 1. Try cached question bank first (instant, no network needed)
    try {
      final cached = await cache.getQuestions(
        subject: _selectedSubject,
        topic: _topicController.text,
        grade: student.student!.grade,
        count: 5,
      );

      if (cached.isNotEmpty) {
        setState(() {
          _questions = cached;
          _loading = false;
          _currentQuestion = 0;
          _selectedAnswer = null;
          _answered = false;
          _score = 0;
          _showResults = false;
          // Using cached questions
        });
        return;
      }
    } catch (_) {
      // Cache miss or error — fall through to AI generation
    }

    // 2. Fall back to AI-generated questions
    final chat = context.read<ChatService>();

    try {
      final questions = await chat.generateTestQuestions(
        subject: _selectedSubject,
        topic: _topicController.text,
        grade: student.student!.grade,
        count: 5,
        studentId: student.student!.id,
      );

      setState(() {
        _questions = questions;
        _loading = false;
        _currentQuestion = 0;
        _selectedAnswer = null;
        _answered = false;
        _score = 0;
        _showResults = false;
        // Using AI-generated questions
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _submitAnswer() {
    if (_selectedAnswer == null) return;

    final correct = _questions[_currentQuestion]['correct'] as int;
    final isCorrect = _selectedAnswer == correct;

    setState(() {
      _answered = true;
      if (isCorrect) _score++;
    });
  }

  void _nextQuestion() {
    if (_currentQuestion < _questions.length - 1) {
      setState(() {
        _currentQuestion++;
        _selectedAnswer = null;
        _answered = false;
      });
    } else {
      setState(() => _showResults = true);
      if (_score == _questions.length) {
        context.read<StudentProvider>().addStars(10);
      } else if (_score >= _questions.length * 0.6) {
        context.read<StudentProvider>().addStars(3);
      } else {
        context.read<StudentProvider>().addStars(1);
      }
      // Save progress to server
      final student = context.read<StudentProvider>().student!;
      ApiService.saveProgress(
        studentId: student.id,
        subject: _selectedSubject,
        topic: _topicController.text,
        score: _score,
        total: _questions.length,
        type: 'test',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF3E5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF9C27B0),
        foregroundColor: Colors.white,
        title: const Row(
          children: [
            Text('🦉 ', style: TextStyle(fontSize: 24)),
            Text('Latihan Ujian',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      body: _showResults
          ? _buildResults(isWide)
          : _questions.isNotEmpty
              ? _buildQuiz(isWide)
              : _buildSetup(isWide),
    );
  }

  Widget _buildSetup(bool isWide) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('📝', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 16),
              const Text(
                'Persiapan Ujian',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Kawi akan buatkan soal latihan untukmu!',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),

              // Subject dropdown
              DropdownButtonFormField<String>(
                value: _selectedSubject,
                decoration: InputDecoration(
                  labelText: 'Mata Pelajaran',
                  prefixIcon: const Icon(Icons.school_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF5F5F5),
                ),
                items: _subjects
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedSubject = v!),
              ),
              const SizedBox(height: 16),

              // Topic field
              TextField(
                controller: _topicController,
                decoration: InputDecoration(
                  labelText: 'Topik / Bab',
                  hintText: 'Contoh: Pecahan dan desimal',
                  prefixIcon: const Icon(Icons.topic_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF5F5F5),
                ),
              ),
              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _generateTest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9C27B0),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _loading
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text('Kawi sedang membuat soal...',
                                style: TextStyle(fontSize: 16)),
                          ],
                        )
                      : const Text(
                          'Buat Soal Latihan! 🚀',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuiz(bool isWide) {
    final q = _questions[_currentQuestion];
    final options = List<String>.from(q['options'] ?? []);
    final correct = q['correct'] as int;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isWide ? 32 : 20),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Progress
              Row(
                children: [
                  Text(
                    'Soal ${_currentQuestion + 1} / ${_questions.length}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Skor: $_score',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF9C27B0),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: (_currentQuestion + 1) / _questions.length,
                backgroundColor: Colors.purple[50],
                color: const Color(0xFF9C27B0),
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 24),

              // Question card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(10),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('🦉', style: TextStyle(fontSize: 24)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            q['question']?.toString() ?? '',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Options
              ...List.generate(options.length, (i) {
                Color bgColor = Colors.white;
                Color borderColor = Colors.grey[300]!;
                Color textColor = Colors.black87;

                if (_answered) {
                  if (i == correct) {
                    bgColor = const Color(0xFFE8F5E9);
                    borderColor = Colors.green;
                    textColor = Colors.green[800]!;
                  } else if (i == _selectedAnswer && i != correct) {
                    bgColor = const Color(0xFFFFEBEE);
                    borderColor = Colors.red;
                    textColor = Colors.red[800]!;
                  }
                } else if (i == _selectedAnswer) {
                  bgColor = const Color(0xFFF3E5F5);
                  borderColor = const Color(0xFF9C27B0);
                  textColor = const Color(0xFF9C27B0);
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _answered
                          ? null
                          : () => setState(() => _selectedAnswer = i),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor, width: 2),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: borderColor.withAlpha(40),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  String.fromCharCode(65 + i), // A, B, C, D
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                options[i],
                                style: TextStyle(
                                  fontSize: 15,
                                  color: textColor,
                                ),
                              ),
                            ),
                            if (_answered && i == correct)
                              const Icon(Icons.check_circle,
                                  color: Colors.green),
                            if (_answered &&
                                i == _selectedAnswer &&
                                i != correct)
                              const Icon(Icons.cancel, color: Colors.red),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),

              // Explanation (after answering)
              if (_answered && q['explanation'] != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3E5F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('💡', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          q['explanation'].toString(),
                          style: const TextStyle(fontSize: 14, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Action button
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _answered
                      ? _nextQuestion
                      : (_selectedAnswer != null ? _submitAnswer : null),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9C27B0),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    _answered
                        ? (_currentQuestion < _questions.length - 1
                            ? 'Soal Berikutnya →'
                            : 'Lihat Hasil')
                        : 'Jawab!',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResults(bool isWide) {
    final percentage = (_score / _questions.length * 100).round();

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(15),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                percentage >= 80 ? '🏆' : percentage >= 60 ? '💪' : '📖',
                style: const TextStyle(fontSize: 64),
              ),
              const SizedBox(height: 16),
              Text(
                '$percentage%',
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF9C27B0),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$_score / ${_questions.length} benar',
                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
              ),
              const SizedBox(height: 12),
              Text(
                percentage >= 80
                    ? 'Luar biasa! Kamu siap ujian! 🌟'
                    : percentage >= 60
                        ? 'Bagus! Latihan lagi supaya lebih mantap!'
                        : 'Yuk belajar lagi, Kawi siap bantu! 🦉',
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Kembali'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _questions = [];
                          _showResults = false;
                          _score = 0;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF9C27B0),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Latihan Lagi'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }
}
