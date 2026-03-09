import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../core/ai/chat_service.dart';
import '../../core/models/student.dart';

enum ChatMode { homework, subject }

class ChatScreen extends StatefulWidget {
  final ChatMode mode;
  final String? subject;

  const ChatScreen({
    super.key,
    required this.mode,
    this.subject,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _picker = ImagePicker();
  bool _hasGreeted = false;

  // Voice input state
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Pulse animation for the mic icon when listening
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.35).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initSpeech();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chat = context.read<ChatService>();
      chat.clearMessages();
      if (widget.subject != null) {
        chat.setSubject(widget.subject!);
      }
      _sendGreeting();
    });
  }

  /// Initialize speech recognition; silently disable if unavailable (e.g. web).
  Future<void> _initSpeech() async {
    try {
      final available = await _speech.initialize(
        onStatus: _onSpeechStatus,
        onError: (error) {
          debugPrint('Speech error: ${error.errorMsg}');
          if (mounted) setState(() => _isListening = false);
          _pulseController.stop();
          _pulseController.reset();
        },
      );
      if (mounted) setState(() => _speechAvailable = available);
    } catch (e) {
      // speech_to_text throws on platforms that don't support it (web, etc.)
      debugPrint('Speech-to-text not available: $e');
      if (mounted) setState(() => _speechAvailable = false);
    }
  }

  void _onSpeechStatus(String status) {
    if (status == 'done' || status == 'notListening') {
      if (mounted) {
        setState(() => _isListening = false);
        _pulseController.stop();
        _pulseController.reset();
      }
    }
  }

  /// Pick the recognition locale based on the current subject.
  String _speechLocale() {
    final subj = (widget.subject ?? '').toLowerCase();
    if (subj.contains('mandarin') || subj.contains('chinese')) {
      return 'zh-CN';
    }
    if (subj.contains('english')) {
      return 'en-US';
    }
    // Default: Bahasa Indonesia
    return 'id-ID';
  }

  Future<void> _toggleListening() async {
    if (!_speechAvailable) {
      _showSpeechUnavailableSnackbar();
      return;
    }

    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      _pulseController.stop();
      _pulseController.reset();
    } else {
      setState(() => _isListening = true);
      _pulseController.repeat(reverse: true);

      await _speech.listen(
        localeId: _speechLocale(),
        listenMode: stt.ListenMode.dictation,
        onResult: (result) {
          setState(() {
            _textController.text = result.recognizedWords;
            _textController.selection = TextSelection.fromPosition(
              TextPosition(offset: _textController.text.length),
            );
          });
        },
      );
    }
  }

  void _showSpeechUnavailableSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Suara tidak tersedia di perangkat ini. '
          'Coba di HP ya!',
        ),
        duration: Duration(seconds: 3),
      ),
    );
  }

  Future<void> _sendGreeting() async {
    if (_hasGreeted) return;
    _hasGreeted = true;

    final student = context.read<StudentProvider>();
    final chat = context.read<ChatService>();

    String greeting;
    if (widget.mode == ChatMode.homework) {
      greeting = 'Halo Budi! Aku mau minta bantuan untuk PR-ku.';
    } else {
      greeting = 'Halo Budi! Aku mau belajar ${widget.subject}.';
    }

    await chat.sendMessage(
      text: greeting,
      studentName: student.student!.name,
      grade: student.student!.grade,
      studentId: student.student!.id,
    );
    _scrollToBottom();
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFF4CAF50)),
                title: const Text('Ambil Foto'),
                subtitle: const Text('Foto soal atau buku'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Color(0xFF2196F3)),
                title: const Text('Pilih dari Galeri'),
                subtitle: const Text('Pilih foto yang sudah ada'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );

    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    _sendWithImage(bytes, picked.name);
  }

  Future<void> _sendWithImage(Uint8List bytes, String name) async {
    final student = context.read<StudentProvider>();
    final chat = context.read<ChatService>();

    await chat.sendMessage(
      text: 'Tolong bantu aku dengan soal di foto ini.',
      studentName: student.student!.name,
      grade: student.student!.grade,
      studentId: student.student!.id,
      imageBytes: bytes,
      imageName: name,
    );
    _scrollToBottom();
  }

  Future<void> _sendText() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    // Stop listening if we were recording
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      _pulseController.stop();
      _pulseController.reset();
    }

    _textController.clear();
    final student = context.read<StudentProvider>();
    final chat = context.read<ChatService>();

    await chat.sendMessage(
      text: text,
      studentName: student.student!.name,
      grade: student.student!.grade,
      studentId: student.student!.id,
    );
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatService>();
    final isWide = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F9F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        title: Row(
          children: [
            const Text('\u{1F989} ', style: TextStyle(fontSize: 24)),
            Text(
              widget.subject != null ? 'Budi \u2014 ${widget.subject}' : 'Budi',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          if (widget.mode == ChatMode.homework)
            IconButton(
              icon: const Icon(Icons.camera_alt),
              tooltip: 'Foto soal',
              onPressed: _pickImage,
            ),
        ],
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: chat.messages.isEmpty && !chat.isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('\u{1F989}', style: TextStyle(fontSize: 64)),
                        const SizedBox(height: 16),
                        Text(
                          'Budi sedang bersiap...',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.all(isWide ? 24 : 16),
                    itemCount: chat.messages.length + (chat.isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == chat.messages.length) {
                        return _TypingIndicator();
                      }
                      final msg = chat.messages[index];
                      // Skip the first user greeting
                      if (index == 0) return const SizedBox.shrink();
                      return _MessageBubble(
                        message: msg,
                        isWide: isWide,
                      );
                    },
                  ),
          ),

          // Listening indicator banner
          if (_isListening)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: const Color(0xFFE8F5E9),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.hearing, size: 18, color: Color(0xFF4CAF50)),
                  const SizedBox(width: 8),
                  Text(
                    _speechLocale() == 'zh-CN'
                        ? 'Budi mendengarkan... (Mandarin)'
                        : _speechLocale() == 'en-US'
                            ? 'Budi mendengarkan... (English)'
                            : 'Budi mendengarkan...',
                    style: const TextStyle(
                      color: Color(0xFF388E3C),
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

          // Input bar
          Container(
            padding: EdgeInsets.fromLTRB(
              isWide ? 24 : 12,
              8,
              isWide ? 24 : 12,
              MediaQuery.of(context).padding.bottom + 8,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(13),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  color: const Color(0xFF4CAF50),
                  onPressed: _pickImage,
                  tooltip: 'Kirim foto',
                ),
                const SizedBox(width: 4),

                // Mic button with pulse animation
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _isListening ? _pulseAnimation.value : 1.0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: _isListening
                              ? const Color(0xFFFF5252)
                              : const Color(0xFFF0F0F0),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(
                            _isListening ? Icons.mic : Icons.mic_none,
                            color: _isListening
                                ? Colors.white
                                : _speechAvailable
                                    ? const Color(0xFF4CAF50)
                                    : Colors.grey,
                          ),
                          onPressed: chat.isLoading ? null : _toggleListening,
                          tooltip: _isListening
                              ? 'Berhenti mendengarkan'
                              : 'Bicara ke Budi',
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 4),

                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: 'Tanya Budi...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF0F0F0),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendText(),
                    maxLines: 3,
                    minLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF4CAF50),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: chat.isLoading ? null : _sendText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _speech.stop();
    _pulseController.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isWide;

  const _MessageBubble({required this.message, required this.isWide});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            const CircleAvatar(
              backgroundColor: Color(0xFF4CAF50),
              radius: 18,
              child: Text('\u{1F989}', style: TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: isWide ? 600 : MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFF4CAF50) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(13),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.imageBytes != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(
                        message.imageBytes!,
                        width: 250,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (isUser)
                    Text(
                      message.content,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                    )
                  else
                    MarkdownBody(
                      data: message.content,
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(fontSize: 15, height: 1.5),
                        strong: const TextStyle(fontWeight: FontWeight.bold),
                        code: TextStyle(
                          backgroundColor: Colors.grey[100],
                          fontFamily: 'monospace',
                          fontSize: 14,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: const Color(0xFF2196F3),
              radius: 18,
              child: Text(
                message.content[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xFF4CAF50),
            radius: 18,
            child: Text('\u{1F989}', style: TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Dot(delay: 0),
                const SizedBox(width: 4),
                _Dot(delay: 200),
                const SizedBox(width: 4),
                _Dot(delay: 400),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({required this.delay});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: Color.lerp(Colors.grey[300], Colors.grey[600], _controller.value),
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
