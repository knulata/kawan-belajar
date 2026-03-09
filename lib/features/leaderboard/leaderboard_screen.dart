import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:animate_do/animate_do.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  static const _apiBaseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:3001',
  );

  String _period = 'week';
  List<Map<String, dynamic>> _leaderboard = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final res = await http.get(
        Uri.parse('$_apiBaseUrl/api/leaderboard?period=$_period'),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _leaderboard = List<Map<String, dynamic>>.from(data['leaderboard']);
          _loading = false;
        });
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  String _periodLabel(String p) {
    switch (p) {
      case 'week': return 'Minggu Ini';
      case 'month': return 'Bulan Ini';
      case 'all': return 'Sepanjang Masa';
      default: return p;
    }
  }

  String _badgeEmoji(String? badge) {
    switch (badge) {
      case 'diamond': return '💎';
      case 'gold': return '🥇';
      case 'silver': return '🥈';
      case 'bronze': return '🥉';
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9F5),
      appBar: AppBar(
        title: const Text('Papan Peringkat'),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Period selector
          Container(
            color: const Color(0xFF4CAF50),
            padding: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
            child: Row(
              children: ['week', 'month', 'all'].map((p) {
                final selected = _period == p;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(_periodLabel(p)),
                      selected: selected,
                      onSelected: (_) {
                        setState(() => _period = p);
                        _fetch();
                      },
                      selectedColor: Colors.white,
                      backgroundColor: Colors.white.withAlpha(50),
                      labelStyle: TextStyle(
                        color: selected ? const Color(0xFF4CAF50) : Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Leaderboard list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _leaderboard.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('🦉', style: TextStyle(fontSize: 48)),
                            SizedBox(height: 8),
                            Text('Belum ada data', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetch,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _leaderboard.length,
                          itemBuilder: (context, index) {
                            final s = _leaderboard[index];
                            final rank = s['rank'] as int;
                            return FadeInUp(
                              delay: Duration(milliseconds: index * 50),
                              child: _buildRow(s, rank),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(Map<String, dynamic> s, int rank) {
    final isTop3 = rank <= 3;
    final rankColors = [null, const Color(0xFFFFD700), const Color(0xFFC0C0C0), const Color(0xFFCD7F32)];
    final rankEmoji = ['', '🥇', '🥈', '🥉'];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isTop3 ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: isTop3
            ? BorderSide(color: rankColors[rank]!.withAlpha(100), width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Rank
            SizedBox(
              width: 40,
              child: isTop3
                  ? Text(rankEmoji[rank], style: const TextStyle(fontSize: 24))
                  : Text(
                      '$rank',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[400],
                      ),
                      textAlign: TextAlign.center,
                    ),
            ),
            const SizedBox(width: 12),
            // Avatar
            CircleAvatar(
              backgroundColor: isTop3 ? rankColors[rank]!.withAlpha(50) : Colors.grey[100],
              child: Text(
                (s['name'] as String? ?? '?')[0].toUpperCase(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isTop3 ? rankColors[rank] : Colors.grey[600],
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Name + grade
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          s['name'] ?? '',
                          style: TextStyle(
                            fontWeight: isTop3 ? FontWeight.bold : FontWeight.w600,
                            fontSize: isTop3 ? 16 : 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (s['badge'] != null) ...[
                        const SizedBox(width: 4),
                        Text(_badgeEmoji(s['badge'])),
                      ],
                    ],
                  ),
                  Text(
                    s['grade'] ?? '',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            // Stars
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${s['stars']}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: isTop3 ? 20 : 16,
                        color: const Color(0xFFFF9800),
                      ),
                    ),
                    const Text(' ⭐', style: TextStyle(fontSize: 14)),
                  ],
                ),
                Text(
                  '${s['active_days'] ?? 0}d aktif',
                  style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
