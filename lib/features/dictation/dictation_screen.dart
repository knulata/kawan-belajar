import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/ai/chat_service.dart';
import '../../core/api/api_service.dart';
import '../../core/models/student.dart';
import '../../core/services/spaced_repetition.dart';

class DictationScreen extends StatefulWidget {
  const DictationScreen({super.key});

  @override
  State<DictationScreen> createState() => _DictationScreenState();
}

class _DictationScreenState extends State<DictationScreen>
    with SingleTickerProviderStateMixin {
  final _lessonController =
      TextEditingController(text: 'Pelajaran 1 - Keluarga');
  final _wordCountController = TextEditingController(text: '5');
  bool _started = false;
  bool _loading = false;
  int _currentWordIndex = 0;
  List<Map<String, String>> _words = [];
  final List<String> _answers = [];
  final List<bool> _results = [];
  final _answerController = TextEditingController();
  bool _showResult = false;
  int _score = 0;

  // Drawing state
  final List<List<Offset?>> _strokes = [];
  List<Offset?> _currentStroke = [];

  // Spaced repetition state
  late TabController _tabController;
  SpacedRepetitionService? _srService;
  int _dueCount = 0;
  bool _isReviewMode = false; // true when practicing review words

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initSpacedRepetition();
  }

  Future<void> _initSpacedRepetition() async {
    final student = context.read<StudentProvider>().student;
    if (student == null) return;
    _srService = SpacedRepetitionService(studentId: student.id);
    await _srService!.load();
    final count = await _srService!.getDueCount();
    if (mounted) {
      setState(() => _dueCount = count);
    }
  }

  Future<void> _refreshDueCount() async {
    if (_srService == null) return;
    final count = await _srService!.getDueCount();
    if (mounted) {
      setState(() => _dueCount = count);
    }
  }

  Future<void> _startDictation() async {
    final count = int.tryParse(_wordCountController.text) ?? 5;
    setState(() {
      _loading = true;
      _words = [];
      _isReviewMode = false;
    });

    final student = context.read<StudentProvider>();
    final chat = context.read<ChatService>();

    try {
      for (int i = 0; i < count; i++) {
        final response = await chat.generateDictationWord(
          lesson: _lessonController.text,
          wordIndex: i + 1,
          studentId: student.student!.id,
        );

        try {
          final jsonStr = response.contains('{')
              ? response.substring(
                  response.indexOf('{'), response.lastIndexOf('}') + 1)
              : response;
          final data = jsonDecode(jsonStr) as Map<String, dynamic>;
          _words.add({
            'word': data['word']?.toString() ?? '',
            'pinyin': data['pinyin']?.toString() ?? '',
            'meaning': data['meaning']?.toString() ?? '',
          });
        } catch (_) {
          _words.add({
            'word': '学习',
            'pinyin': 'xué xí',
            'meaning': 'belajar',
          });
        }
      }

      setState(() {
        _started = true;
        _loading = false;
        _currentWordIndex = 0;
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

  Future<void> _startReview() async {
    if (_srService == null) return;

    setState(() => _loading = true);

    final dueWords = await _srService!.getDueWords();
    if (dueWords.isEmpty) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak ada kata untuk direview!')),
        );
      }
      return;
    }

    setState(() {
      _words = dueWords
          .map((c) => {
                'word': c.word,
                'pinyin': c.pinyin,
                'meaning': c.meaning,
              })
          .toList();
      _isReviewMode = true;
      _started = true;
      _loading = false;
      _currentWordIndex = 0;
      _answers.clear();
      _results.clear();
      _score = 0;
      _showResult = false;
    });
  }

  void _checkAnswer() {
    final answer = _answerController.text.trim();
    final correct = _words[_currentWordIndex]['word'] ?? '';
    final isCorrect = answer == correct;

    setState(() {
      _answers.add(answer);
      _results.add(isCorrect);
      if (isCorrect) _score++;
    });

    // Record in spaced repetition system
    if (_srService != null) {
      // Map correctness to SM-2 quality:
      // correct → 4 (good), wrong → 0 (wrong)
      final quality = isCorrect ? 4 : 0;
      _srService!.recordAnswer(_words[_currentWordIndex], quality);
    }

    // Show feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isCorrect
              ? '太棒了! Benar! ⭐'
              : '答案是: $correct (${_words[_currentWordIndex]['pinyin']})',
        ),
        backgroundColor: isCorrect ? Colors.green : Colors.orange,
        duration: const Duration(seconds: 2),
      ),
    );

    // Next word or finish
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      if (_currentWordIndex < _words.length - 1) {
        setState(() {
          _currentWordIndex++;
          _answerController.clear();
          _strokes.clear();
          _currentStroke = [];
        });
      } else {
        setState(() => _showResult = true);
        _refreshDueCount();
        if (_score == _words.length) {
          context.read<StudentProvider>().addStars(5);
        } else if (_score > 0) {
          context.read<StudentProvider>().addStars(1);
        }
        // Save progress to server
        final student = context.read<StudentProvider>().student!;
        ApiService.saveProgress(
          studentId: student.id,
          subject: 'Bahasa Mandarin',
          topic: _isReviewMode ? 'Review Dikte' : _lessonController.text,
          score: _score,
          total: _words.length,
          type: 'dictation',
        );
      }
    });
  }

  void _clearCanvas() {
    setState(() {
      _strokes.clear();
      _currentStroke = [];
    });
  }

  void _resetSession() {
    setState(() {
      _started = false;
      _showResult = false;
      _words = [];
      _answers.clear();
      _results.clear();
      _score = 0;
      _currentWordIndex = 0;
      _isReviewMode = false;
      _answerController.clear();
      _strokes.clear();
      _currentStroke = [];
    });
    _refreshDueCount();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8E1),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE53935),
        foregroundColor: Colors.white,
        title: const Row(
          children: [
            Text('🦉 ', style: TextStyle(fontSize: 24)),
            Text('Dikte Mandarin 听写',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      body: _showResult
          ? _buildResults(isWide)
          : _started
              ? _buildDictation(isWide)
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
              const Text('✍️', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 16),
              const Text(
                'Latihan Dikte',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Kawi akan bacakan kata-kata, kamu tulis jawabannya!',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Tab bar: New Words | Review
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: const Color(0xFFE53935),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.grey[700],
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  tabs: [
                    const Tab(text: 'Kata Baru'),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Review'),
                          if (_dueCount > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: _tabController.index == 1
                                    ? Colors.white
                                    : const Color(0xFFE53935),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$_dueCount',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _tabController.index == 1
                                      ? const Color(0xFFE53935)
                                      : Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Tab content
              SizedBox(
                height: 260,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // New Words tab
                    _buildNewWordsTab(),
                    // Review tab
                    _buildReviewTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNewWordsTab() {
    return Column(
      children: [
        TextField(
          controller: _lessonController,
          decoration: InputDecoration(
            labelText: 'Pelajaran / Topik',
            hintText: 'Contoh: Pelajaran 3 - Hewan',
            prefixIcon: const Icon(Icons.book_outlined),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: const Color(0xFFF5F5F5),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _wordCountController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Jumlah kata',
            prefixIcon: const Icon(Icons.format_list_numbered),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: const Color(0xFFF5F5F5),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _loading ? null : _startDictation,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _loading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : const Text(
                    '开始! Mulai!',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewTab() {
    if (_dueCount == 0) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🎉', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          const Text(
            'Tidak ada kata untuk direview!',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Mulai latihan kata baru dulu, nanti kata-kata itu\nakan muncul di sini untuk direview.',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.orange[200]!),
          ),
          child: Column(
            children: [
              const Text('📖', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 8),
              Text(
                '$_dueCount kata siap direview',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Review kata-kata yang sudah dipelajari\nagar tidak lupa!',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _loading ? null : _startReview,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _loading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : const Text(
                    '复习! Review!',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildDictation(bool isWide) {
    final word = _words[_currentWordIndex];

    return Padding(
      padding: EdgeInsets.all(isWide ? 32 : 16),
      child: Column(
        children: [
          // Progress
          Row(
            children: [
              if (_isReviewMode)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '复习 Review',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange[800],
                    ),
                  ),
                ),
              Text(
                'Kata ${_currentWordIndex + 1} / ${_words.length}',
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
                  color: Color(0xFFE53935),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (_currentWordIndex + 1) / _words.length,
            backgroundColor: _isReviewMode ? Colors.orange[50] : Colors.red[50],
            color: _isReviewMode ? Colors.orange : const Color(0xFFE53935),
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 24),

          // Hint card with pinyin & meaning
          Container(
            padding: const EdgeInsets.all(20),
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
              children: [
                const Text('🦉 Kawi bilang:',
                    style: TextStyle(fontSize: 14, color: Colors.grey)),
                const SizedBox(height: 8),
                Text(
                  '请写: "${word['pinyin']}"',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Artinya: ${word['meaning']}',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Writing canvas
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Stack(
                children: [
                  // Grid lines
                  CustomPaint(
                    size: Size.infinite,
                    painter: _GridPainter(),
                  ),
                  // Drawing area
                  GestureDetector(
                    onPanStart: (details) {
                      setState(() {
                        _currentStroke = [details.localPosition];
                      });
                    },
                    onPanUpdate: (details) {
                      setState(() {
                        _currentStroke.add(details.localPosition);
                      });
                    },
                    onPanEnd: (_) {
                      setState(() {
                        _strokes.add(List.from(_currentStroke));
                        _currentStroke = [];
                      });
                    },
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: _StrokePainter(
                        strokes: _strokes,
                        currentStroke: _currentStroke,
                      ),
                    ),
                  ),
                  // Clear button
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: _clearCanvas,
                      tooltip: 'Hapus',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Type answer
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _answerController,
                  decoration: InputDecoration(
                    hintText: 'Ketik jawaban (汉字)...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  style: const TextStyle(fontSize: 24),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _checkAnswer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE53935),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('检查', style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResults(bool isWide) {
    final percentage = (_score / _words.length * 100).round();

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
              if (_isReviewMode)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '复习 Review',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange[800],
                    ),
                  ),
                ),
              Text(
                percentage >= 80 ? '🎉' : percentage >= 50 ? '💪' : '📚',
                style: const TextStyle(fontSize: 56),
              ),
              const SizedBox(height: 16),
              Text(
                '$percentage%',
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE53935),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$_score / ${_words.length} benar',
                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Text(
                percentage >= 80
                    ? '太棒了! Hebat sekali! ⭐⭐⭐'
                    : percentage >= 50
                        ? '不错! Bagus, terus berlatih!'
                        : '加油! Semangat, coba lagi ya!',
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Word list review
              ...List.generate(_words.length, (i) {
                final correct = i < _results.length && _results[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(
                        correct ? Icons.check_circle : Icons.cancel,
                        color: correct ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _words[i]['word'] ?? '',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _words[i]['pinyin'] ?? '',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const Spacer(),
                      if (i < _answers.length && !correct)
                        Text(
                          _answers[i],
                          style: const TextStyle(
                            color: Colors.red,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                    ],
                  ),
                );
              }),

              if (_dueCount > 0) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Text('📖', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$_dueCount kata lagi perlu direview',
                          style: TextStyle(
                            color: Colors.orange[800],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _resetSession,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE53935),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Latihan Lagi',
                            style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Kembali',
                          style: TextStyle(fontSize: 16)),
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
    _lessonController.dispose();
    _wordCountController.dispose();
    _answerController.dispose();
    _tabController.dispose();
    super.dispose();
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withAlpha(30)
      ..strokeWidth = 1;

    // Dashed center lines
    final dashPaint = Paint()
      ..color = Colors.grey.withAlpha(60)
      ..strokeWidth = 1;

    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      dashPaint,
    );
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      dashPaint,
    );

    // Diagonal guides
    canvas.drawLine(Offset.zero, Offset(size.width, size.height), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(0, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StrokePainter extends CustomPainter {
  final List<List<Offset?>> strokes;
  final List<Offset?> currentStroke;

  _StrokePainter({required this.strokes, required this.currentStroke});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black87
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      _drawStroke(canvas, stroke, paint);
    }
    _drawStroke(canvas, currentStroke, paint);
  }

  void _drawStroke(Canvas canvas, List<Offset?> points, Paint paint) {
    if (points.length < 2) return;
    final path = ui.Path();
    path.moveTo(points.first!.dx, points.first!.dy);
    for (int i = 1; i < points.length; i++) {
      if (points[i] != null) {
        path.lineTo(points[i]!.dx, points[i]!.dy);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
