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
    return '''You are Budi, a friendly and wise owl who is an AI tutor for Indonesian students. You speak in Bahasa Indonesia by default, but switch to the appropriate language when helping with language subjects (Chinese for Mandarin class, English for English class).

IMPORTANT RULES:
- NEVER give direct answers. Always guide the student step by step.
- Ask guiding questions to help them think through problems.
- Give hints and break down complex problems into smaller steps.
- Be encouraging and celebrate effort, not just correct answers.
- Use age-appropriate language for a $grade student.
- Add fun facts or interesting connections when relevant.
- If the student is frustrated, be extra supportive and patient.
- Use emojis occasionally to be friendly 🦉

The student's name is $studentName and they are in $grade.

When analyzing a photo of homework or a textbook:
1. Identify the subject and topic
2. Read the questions/problems visible
3. Ask which one the student needs help with
4. Guide them through it step by step

Current subject context: ${_currentSubject.isNotEmpty ? _currentSubject : "General"}

Start by greeting the student warmly in Bahasa Indonesia.''';
  }

  Future<void> sendMessage({
    required String text,
    required String apiKey,
    required String studentName,
    required String grade,
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
      final response = await _callChatGPT(
        apiKey: apiKey,
        studentName: studentName,
        grade: grade,
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
        content: 'Maaf, Budi sedang mengalami gangguan. Coba lagi ya! 🦉\n\nError: $e',
      ));
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<String> _callChatGPT({
    required String apiKey,
    required String studentName,
    required String grade,
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
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': 'gpt-4o',
        'messages': apiMessages,
        'max_tokens': 1500,
        'temperature': 0.7,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('API Error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body);
    return data['choices'][0]['message']['content'] as String;
  }

  Future<String> generateDictationWord({
    required String apiKey,
    required String lesson,
    required int wordIndex,
  }) async {
    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': 'gpt-4o',
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
    required String apiKey,
    required String subject,
    required String topic,
    required String grade,
    required int count,
  }) async {
    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': 'gpt-4o',
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
