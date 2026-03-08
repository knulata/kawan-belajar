import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import '../../core/models/parent_data.dart';
import '../../core/models/student.dart';
import 'parent_setup_screen.dart';
import 'add_reminder_screen.dart';

class ParentDashboardScreen extends StatelessWidget {
  const ParentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final parentData = context.watch<ParentDataProvider>();
    final student = context.watch<StudentProvider>().student!;
    final isWide = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF7B1FA2),
        foregroundColor: Colors.white,
        title: const Row(
          children: [
            Text('👨‍👩‍👧 ', style: TextStyle(fontSize: 24)),
            Text('Laporan Orang Tua',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Pengaturan',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ParentSetupScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddReminderScreen()),
        ),
        backgroundColor: const Color(0xFF7B1FA2),
        icon: const Icon(Icons.alarm_add, color: Colors.white),
        label:
            const Text('Tambah Pengingat', style: TextStyle(color: Colors.white)),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isWide ? 32 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Student info header
            FadeInDown(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF9C27B0), Color(0xFF7B1FA2)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white,
                      child: Text(
                        student.name[0].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF7B1FA2),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            student.name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            student.grade,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withAlpha(200),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        Text(
                          '${parentData.streakDays}',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'hari berturut',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withAlpha(200),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Quick stats row
            FadeInUp(
              delay: const Duration(milliseconds: 100),
              child: GridView.count(
                crossAxisCount: isWide ? 4 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: isWide ? 1.8 : 1.4,
                children: [
                  _StatCard(
                    icon: '📚',
                    value: '${parentData.totalSessions}',
                    label: 'Total Sesi',
                    color: const Color(0xFF2196F3),
                  ),
                  _StatCard(
                    icon: '⏱️',
                    value: _formatMinutes(parentData.totalMinutes),
                    label: 'Waktu Belajar',
                    color: const Color(0xFF4CAF50),
                  ),
                  _StatCard(
                    icon: '⭐',
                    value: '${parentData.totalStars}',
                    label: 'Bintang',
                    color: const Color(0xFFFF9800),
                  ),
                  _StatCard(
                    icon: '📝',
                    value: parentData.averageTestScore > 0
                        ? '${parentData.averageTestScore.round()}%'
                        : '-',
                    label: 'Rata-rata Ujian',
                    color: const Color(0xFFE91E63),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // WhatsApp status
            if (!parentData.isParentLinked)
              FadeInUp(
                delay: const Duration(milliseconds: 150),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF4CAF50)),
                  ),
                  child: Row(
                    children: [
                      const Text('📱', style: TextStyle(fontSize: 32)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Hubungkan WhatsApp Orang Tua',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Dapatkan laporan harian & pengingat PR/ujian langsung ke WhatsApp!',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ParentSetupScreen()),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Hubungkan'),
                      ),
                    ],
                  ),
                ),
              ),

            if (parentData.isParentLinked) ...[
              FadeInUp(
                delay: const Duration(milliseconds: 150),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Text('✅', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'WhatsApp terhubung: ${parentData.parentName} (${parentData.parentPhone})',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      Switch(
                        value: parentData.whatsappAlertsEnabled,
                        onChanged: (v) => parentData.toggleWhatsappAlerts(v),
                        activeColor: const Color(0xFF25D366),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Upcoming reminders
            FadeInUp(
              delay: const Duration(milliseconds: 200),
              child: const Text(
                'Pengingat Mendatang',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),

            if (parentData.upcomingReminders.isEmpty)
              FadeInUp(
                delay: const Duration(milliseconds: 250),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        const Text('📅', style: TextStyle(fontSize: 40)),
                        const SizedBox(height: 8),
                        Text(
                          'Belum ada pengingat',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tambahkan pengingat PR atau ujian!',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              ...parentData.upcomingReminders.map(
                (r) => FadeInUp(
                  delay: const Duration(milliseconds: 250),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _ReminderCard(
                      reminder: r,
                      onDelete: () => parentData.removeReminder(r.id),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 24),

            // Subject breakdown
            FadeInUp(
              delay: const Duration(milliseconds: 300),
              child: const Text(
                'Waktu Per Mata Pelajaran',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),

            if (parentData.subjectBreakdown.isEmpty)
              FadeInUp(
                delay: const Duration(milliseconds: 350),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      'Belum ada data belajar',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  ),
                ),
              )
            else
              FadeInUp(
                delay: const Duration(milliseconds: 350),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: parentData.subjectBreakdown.entries.map((e) {
                      final maxMinutes = parentData.subjectBreakdown.values
                          .fold(0, (a, b) => a > b ? a : b);
                      final fraction =
                          maxMinutes > 0 ? e.value / maxMinutes : 0.0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 100,
                              child: Text(
                                e.key,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: fraction,
                                  backgroundColor: Colors.grey[100],
                                  color: const Color(0xFF7B1FA2),
                                  minHeight: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatMinutes(e.value),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            const SizedBox(height: 24),

            // Recent activity
            FadeInUp(
              delay: const Duration(milliseconds: 400),
              child: const Text(
                'Aktivitas Terbaru',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),

            if (parentData.sessions.isEmpty)
              FadeInUp(
                delay: const Duration(milliseconds: 450),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        const Text('🦉', style: TextStyle(fontSize: 40)),
                        const SizedBox(height: 8),
                        Text(
                          'Belum ada aktivitas belajar',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              ...parentData.sessions.reversed.take(10).map(
                    (s) => FadeInUp(
                      delay: const Duration(milliseconds: 450),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _ActivityCard(session: s),
                      ),
                    ),
                  ),
            const SizedBox(height: 80), // Space for FAB
          ],
        ),
      ),
    );
  }

  String _formatMinutes(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return mins > 0 ? '${hours}j ${mins}m' : '${hours}j';
  }
}

class _StatCard extends StatelessWidget {
  final String icon;
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(20),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  final ScheduledReminder reminder;
  final VoidCallback onDelete;

  const _ReminderCard({required this.reminder, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isTest = reminder.type == 'test';
    final daysLeft = reminder.dueDate.difference(DateTime.now()).inDays;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: daysLeft <= 1
              ? Colors.red.withAlpha(100)
              : Colors.grey.withAlpha(50),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isTest
                  ? const Color(0xFFFCE4EC)
                  : const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                isTest ? '📝' : '📚',
                style: const TextStyle(fontSize: 22),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reminder.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${reminder.subject} — ${_formatDate(reminder.dueDate)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          if (daysLeft <= 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                daysLeft <= 0 ? 'Hari ini!' : 'Besok!',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.red[700],
                ),
              ),
            )
          else
            Text(
              '$daysLeft hari lagi',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          const SizedBox(width: 4),
          if (reminder.whatsappEnabled)
            const Icon(Icons.message, size: 16, color: Color(0xFF25D366)),
          IconButton(
            icon: Icon(Icons.close, size: 18, color: Colors.grey[400]),
            onPressed: onDelete,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agt', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    return '${date.day} ${months[date.month - 1]}';
  }
}

class _ActivityCard extends StatelessWidget {
  final StudySession session;

  const _ActivityCard({required this.session});

  @override
  Widget build(BuildContext context) {
    String icon;
    switch (session.type) {
      case 'dictation':
        icon = '✍️';
        break;
      case 'test_prep':
        icon = '📝';
        break;
      default:
        icon = '💬';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.subject,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${session.durationMinutes} menit${session.testScore != null ? ' — Skor: ${session.testScore}/${session.testTotal}' : ''}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          if (session.starsEarned > 0)
            Row(
              children: [
                const Text('⭐', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 2),
                Text(
                  '+${session.starsEarned}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF9800),
                  ),
                ),
              ],
            ),
          const SizedBox(width: 8),
          Text(
            _formatTimeAgo(session.date),
            style: TextStyle(fontSize: 11, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m lalu';
    if (diff.inHours < 24) return '${diff.inHours}j lalu';
    if (diff.inDays < 7) return '${diff.inDays}h lalu';
    return '${date.day}/${date.month}';
  }
}
