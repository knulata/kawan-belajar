import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import '../../core/models/student.dart';
import '../../core/api/api_service.dart';
import '../chat/chat_screen.dart';
import '../dictation/dictation_screen.dart';
import '../test_prep/test_prep_screen.dart';
import '../progress/progress_screen.dart';
import '../leaderboard/leaderboard_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _assignments = [];

  @override
  void initState() {
    super.initState();
    _loadAssignments();
    _registerStudent();
  }

  Future<void> _registerStudent() async {
    final student = context.read<StudentProvider>().student!;
    await ApiService.registerStudent(name: student.name, grade: student.grade);
  }

  Future<void> _loadAssignments() async {
    final student = context.read<StudentProvider>().student!;
    final assignments = await ApiService.getAssignments(grade: student.grade);
    if (mounted) {
      setState(() => _assignments = assignments);
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Selamat Pagi';
    if (hour < 15) return 'Selamat Siang';
    if (hour < 18) return 'Selamat Sore';
    return 'Selamat Malam';
  }

  @override
  Widget build(BuildContext context) {
    final student = context.watch<StudentProvider>().student!;
    final isWide = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F9F5),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isWide ? 32 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top bar
              Row(
                children: [
                  Expanded(
                    child: FadeInLeft(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_getGreeting()}!',
                            style: TextStyle(
                              fontSize: isWide ? 16 : 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            student.name,
                            style: TextStyle(
                              fontSize: isWide ? 28 : 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  FadeInRight(
                    child: Row(
                      children: [
                        // Stars
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              const Text('⭐', style: TextStyle(fontSize: 18)),
                              const SizedBox(width: 6),
                              Text(
                                '${student.stars}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFFF9800),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Leaderboard button
                        IconButton(
                          icon: const Icon(Icons.leaderboard_rounded),
                          color: const Color(0xFFFF9800),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LeaderboardScreen(),
                            ),
                          ),
                          tooltip: 'Papan Peringkat',
                        ),
                        // Progress button
                        IconButton(
                          icon: const Icon(Icons.bar_chart_rounded),
                          color: const Color(0xFF4CAF50),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ProgressScreen(),
                            ),
                          ),
                          tooltip: 'Lihat Progress',
                        ),
                        // Profile menu
                        PopupMenuButton(
                          icon: CircleAvatar(
                            backgroundColor: const Color(0xFF4CAF50),
                            child: Text(
                              student.name[0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              enabled: false,
                              child: Text(
                                '${student.grade} | Level ${student.level}',
                              ),
                            ),
                            PopupMenuItem(
                              child: const Row(
                                children: [
                                  Icon(Icons.bar_chart, size: 18),
                                  SizedBox(width: 8),
                                  Text('Progressku'),
                                ],
                              ),
                              onTap: () => Future.delayed(
                                Duration.zero,
                                () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ProgressScreen(),
                                  ),
                                ),
                              ),
                            ),
                            PopupMenuItem(
                              child: const Row(
                                children: [
                                  Icon(Icons.leaderboard, size: 18),
                                  SizedBox(width: 8),
                                  Text('Peringkat'),
                                ],
                              ),
                              onTap: () => Future.delayed(
                                Duration.zero,
                                () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const LeaderboardScreen(),
                                  ),
                                ),
                              ),
                            ),
                            PopupMenuItem(
                              child: const Row(
                                children: [
                                  Icon(Icons.logout, size: 18),
                                  SizedBox(width: 8),
                                  Text('Keluar'),
                                ],
                              ),
                              onTap: () =>
                                  context.read<StudentProvider>().logout(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Budi greeting card
              FadeInUp(
                delay: const Duration(milliseconds: 200),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF66BB6A), Color(0xFF43A047)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4CAF50).withAlpha(60),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Text('🦉', style: TextStyle(fontSize: 52)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Halo dari Budi!',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Mau belajar apa hari ini? Foto PR-mu atau pilih pelajaran di bawah!',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withAlpha(230),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Upcoming assignments
              if (_assignments.isNotEmpty) ...[
                FadeInUp(
                  delay: const Duration(milliseconds: 250),
                  child: const Text(
                    'Tugas & Ujian Mendatang',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FadeInUp(
                  delay: const Duration(milliseconds: 300),
                  child: SizedBox(
                    height: 100,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _assignments.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final a = _assignments[index];
                        final isTest = a['type'] == 'test';
                        return Container(
                          width: 220,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isTest
                                ? const Color(0xFFFFF3E0)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isTest
                                  ? const Color(0xFFFF9800)
                                  : Colors.grey[200]!,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    isTest ? '📝' : '📚',
                                    style: const TextStyle(fontSize: 18),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      a['title'] ?? '',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${a['subject'] ?? ''} — ${a['topic'] ?? ''}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Deadline: ${a['due_date'] ?? '-'}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isTest
                                      ? const Color(0xFFE65100)
                                      : Colors.grey[500],
                                  fontWeight: isTest
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Quick actions
              FadeInUp(
                delay: const Duration(milliseconds: 350),
                child: const Text(
                  'Mau ngapain?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Main action cards
              FadeInUp(
                delay: const Duration(milliseconds: 400),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final crossCount = isWide ? 3 : 1;
                    return GridView.count(
                      crossAxisCount: crossCount,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: isWide ? 1.6 : 2.8,
                      children: [
                        _ActionCard(
                          icon: '📸',
                          title: 'Foto PR',
                          subtitle: 'Foto soal, Budi bantu jawab',
                          color: const Color(0xFF2196F3),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const ChatScreen(mode: ChatMode.homework),
                            ),
                          ),
                        ),
                        _ActionCard(
                          icon: '✍️',
                          title: 'Dikte Mandarin',
                          subtitle: 'Latihan menulis 听写',
                          color: const Color(0xFFE53935),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const DictationScreen(),
                            ),
                          ),
                        ),
                        _ActionCard(
                          icon: '📝',
                          title: 'Latihan Ujian',
                          subtitle: 'Persiapan ulangan & tes',
                          color: const Color(0xFF9C27B0),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TestPrepScreen(),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 32),

              // Subject grid
              FadeInUp(
                delay: const Duration(milliseconds: 500),
                child: const Text(
                  'Mata Pelajaran',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              FadeInUp(
                delay: const Duration(milliseconds: 600),
                child: GridView.count(
                  crossAxisCount: isWide ? 4 : 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: isWide ? 1.4 : 1.3,
                  children: [
                    _SubjectTile(
                      emoji: '🔢',
                      name: 'Matematika',
                      onTap: () => _openSubject(context, 'Matematika'),
                    ),
                    _SubjectTile(
                      emoji: '🇮🇩',
                      name: 'B. Indonesia',
                      onTap: () => _openSubject(context, 'Bahasa Indonesia'),
                    ),
                    _SubjectTile(
                      emoji: '🇨🇳',
                      name: 'Mandarin',
                      onTap: () => _openSubject(context, 'Bahasa Mandarin'),
                    ),
                    _SubjectTile(
                      emoji: '🔬',
                      name: 'IPA',
                      onTap: () => _openSubject(context, 'IPA (Sains)'),
                    ),
                    _SubjectTile(
                      emoji: '🌍',
                      name: 'IPS',
                      onTap: () => _openSubject(context, 'IPS'),
                    ),
                    _SubjectTile(
                      emoji: '🇬🇧',
                      name: 'English',
                      onTap: () => _openSubject(context, 'English'),
                    ),
                    _SubjectTile(
                      emoji: '🏛️',
                      name: 'PKN',
                      onTap: () => _openSubject(context, 'PKN'),
                    ),
                    _SubjectTile(
                      emoji: '📖',
                      name: 'Lainnya',
                      onTap: () => _openSubject(context, 'Umum'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openSubject(BuildContext context, String subject) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          mode: ChatMode.subject,
          subject: subject,
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      shadowColor: color.withAlpha(40),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(icon, style: const TextStyle(fontSize: 28)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubjectTile extends StatelessWidget {
  final String emoji;
  final String name;
  final VoidCallback onTap;

  const _SubjectTile({
    required this.emoji,
    required this.name,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 36)),
            const SizedBox(height: 8),
            Text(
              name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
