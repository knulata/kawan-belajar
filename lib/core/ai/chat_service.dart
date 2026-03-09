import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';

class ChatMessage {
  final String role; // 'user', 'assistant'
  final String content;
  final Uint8List? imageBytes;
  final DateTime timestamp;

  ChatMessage({
    required this.role,
    required this.content,
    this.imageBytes,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class ChatService extends ChangeNotifier {
  // API base URL — set via --dart-define=API_URL=https://your-server.com
  // Defaults to localhost for development
  static const _apiBaseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:3001',
  );

  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  String _currentSubject = '';

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  String get currentSubject => _currentSubject;

  void setSubject(String subject) {
    _currentSubject = subject;
    notifyListeners();
  }

  void clearMessages() {
    _messages.clear();
    _currentSubject = '';
    notifyListeners();
  }

  String _buildSystemPrompt(String studentName, String grade) {
    return '''You are Kawi, a friendly and wise owl who is an AI tutor for Indonesian students. You speak in Bahasa Indonesia by default, but switch to the appropriate language when helping with language subjects (Chinese for Mandarin class, English for English class).

CRITICAL RULES — These make you DIFFERENT from ChatGPT:
- NEVER give direct answers. This is the #1 rule. ALWAYS guide step by step.
- When a student asks "what is the answer?", respond with a guiding question instead.
- Break problems into small steps. Ask the student to try each step.
- Only confirm when the student arrives at the answer themselves.
- If they're stuck for 3+ turns, give a bigger hint but still don't give the answer.
- Celebrate EFFORT, not just correct answers. "Bagus, kamu sudah coba! 💪"

TEACHING STYLE:
- Use the Socratic method — ask questions that lead to understanding.
- Give real-world examples relevant to Indonesian kids' daily life.
- For math: ask "what do you think the first step is?" before showing anything.
- For languages: give context clues, not translations.
- For science: connect to things they can see/touch.
- Use age-appropriate language for a $grade student.
- Add fun facts to make learning interesting.
- Use emojis to be friendly 🦉

PERSONALITY:
- You're warm, patient, and never judgmental.
- If the student is frustrated, acknowledge it: "Aku tahu ini susah, tapi kamu pasti bisa!"
- You remember what they struggled with and refer back to it.
- You occasionally crack age-appropriate jokes.

The student's name is $studentName and they are in $grade.

When analyzing a photo of homework or a textbook:
1. Identify ALL questions/problems visible in the photo
2. List them briefly: "Aku lihat ada soal 1, 2, 3... Mau mulai dari yang mana?"
3. When they pick one, guide them through it step by step
4. After solving one, ask if they want to try the next one

Current subject context: ${_currentSubject.isNotEmpty ? _currentSubject : "General"}

Start by greeting the student warmly in Bahasa Indonesia. Use their name.''';
  }

  Future<void> sendMessage({
    required String text,
    required String studentName,
    required String grade,
    String? studentId,
    Uint8List? imageBytes,
    String? imageName,
  }) async {
    // Add user message
    _messages.add(ChatMessage(
      role: 'user',
      content: text,
      imageBytes: imageBytes,
    ));
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _callAPI(
        studentName: studentName,
        grade: grade,
        studentId: studentId,
        imageBytes: imageBytes,
        imageName: imageName,
      );

      _messages.add(ChatMessage(
        role: 'assistant',
        content: response,
      ));
    } catch (e) {
      _messages.add(ChatMessage(
        role: 'assistant',
        content: 'Maaf, Kawi sedang istirahat sebentar. Coba lagi ya! 🦉\n\nError: $e',
      ));
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<String> _callAPI({
    required String studentName,
    required String grade,
    String? studentId,
    Uint8List? imageBytes,
    String? imageName,
  }) async {
    final systemPrompt = _buildSystemPrompt(studentName, grade);

    // Build messages for API
    final apiMessages = <Map<String, dynamic>>[
      {'role': 'system', 'content': systemPrompt},
    ];

    for (final msg in _messages) {
      if (msg.imageBytes != null) {
        final mimeType = lookupMimeType(imageName ?? 'image.jpg') ?? 'image/jpeg';
        final base64Image = base64Encode(msg.imageBytes!);
        apiMessages.add({
          'role': msg.role,
          'content': [
            {'type': 'text', 'text': msg.content},
            {
              'type': 'image_url',
              'image_url': {
                'url': 'data:$mimeType;base64,$base64Image',
              },
            },
          ],
        });
      } else {
        apiMessages.add({
          'role': msg.role,
          'content': msg.content,
        });
      }
    }

    final response = await http.post(
      Uri.parse('$_apiBaseUrl/api/chat'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'messages': apiMessages,
        'student_id': studentId ?? studentName,
        'max_tokens': 1500,
        'temperature': 0.7,
      }),
    );

    if (response.statusCode == 429) {
      throw Exception('Terlalu banyak pertanyaan. Tunggu sebentar ya!');
    }

    if (response.statusCode != 200) {
      throw Exception('Kawi sedang sibuk (${response.statusCode})');
    }

    final data = jsonDecode(response.body);
    return data['choices'][0]['message']['content'] as String;
  }

  Future<String> generateDictationWord({
    required String lesson,
    required int wordIndex,
    String? studentId,
  }) async {
    final response = await http.post(
      Uri.parse('$_apiBaseUrl/api/chat'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'messages': [
          {
            'role': 'system',
            'content':
                'You are a Chinese language teacher. Generate a Chinese word/phrase for dictation practice. Return ONLY a JSON object with: {"word": "chinese characters", "pinyin": "pinyin with tones", "meaning": "meaning in Bahasa Indonesia"}. No other text.',
          },
          {
            'role': 'user',
            'content':
                'Generate word #$wordIndex for lesson: "$lesson". Make it appropriate for Indonesian elementary/middle school students learning Chinese.',
          },
        ],
        'student_id': studentId ?? 'dictation',
        'max_tokens': 100,
        'temperature': 0.8,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('API Error: ${response.body}');
    }

    final data = jsonDecode(response.body);
    return data['choices'][0]['message']['content'] as String;
  }

  Future<List<Map<String, dynamic>>> generateTestQuestions({
    required String subject,
    required String topic,
    required String grade,
    required int count,
    String? studentId,
  }) async {
    final response = await http.post(
      Uri.parse('$_apiBaseUrl/api/chat'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'messages': [
          {
            'role': 'system',
            'content':
                'You are a test question generator for Indonesian school students. Generate questions in the appropriate language for the subject. Return ONLY a JSON array of objects with: {"question": "...", "options": ["A", "B", "C", "D"], "correct": 0, "explanation": "..."}. The "correct" field is the index (0-3) of the correct option.',
          },
          {
            'role': 'user',
            'content':
                'Generate $count multiple choice questions for subject: $subject, topic: "$topic", grade: $grade.',
          },
        ],
        'student_id': studentId ?? 'testprep',
        'max_tokens': 2000,
        'temperature': 0.7,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('API Error: ${response.body}');
    }

    final data = jsonDecode(response.body);
    final content = data['choices'][0]['message']['content'] as String;

    // Extract JSON from response
    final jsonStr = content.contains('[')
        ? content.substring(content.indexOf('['), content.lastIndexOf(']') + 1)
        : '[]';

    return List<Map<String, dynamic>>.from(jsonDecode(jsonStr));
  }
}
