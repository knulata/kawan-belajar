import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Offline-capable question bank cache.
///
/// Downloads all question banks from the server on first launch or when
/// [refreshCache] is called. Falls back to cached data when the server
/// is unreachable.
class QuestionCache {
  static const _apiBaseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:3001',
  );

  /// SharedPreferences keys
  static const _cacheKey = 'question_bank_cache';
  static const _lastSyncKey = 'question_bank_last_sync';

  /// How long before we consider the cache stale (24 hours).
  static const _staleDuration = Duration(hours: 24);

  /// In-memory parsed cache (so we only deserialize once).
  Map<String, dynamic>? _memoryCache;

  /// Singleton instance
  static final QuestionCache _instance = QuestionCache._internal();
  factory QuestionCache() => _instance;
  QuestionCache._internal();

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Returns questions for a given [subject] and [topic].
  ///
  /// Optionally filter by [grade]. Returns up to [count] questions in random
  /// order. If no cached data is available, returns an empty list.
  Future<List<Map<String, dynamic>>> getQuestions({
    required String subject,
    required String topic,
    String? grade,
    int count = 5,
  }) async {
    final cache = await _ensureCache();
    if (cache == null) return [];

    final subjects = cache['subjects'] as List<dynamic>? ?? [];

    // Find the matching subject (fuzzy match on name)
    final subjectData = _findSubject(subjects, subject);
    if (subjectData == null) return [];

    final grades = subjectData['grades'] as Map<String, dynamic>? ?? {};

    // Collect questions from matching topics across grades
    List<Map<String, dynamic>> questions = [];

    for (final entry in grades.entries) {
      // If grade filter is set, skip non-matching grades
      if (grade != null && grade.isNotEmpty && !_gradeMatches(entry.key, grade)) {
        continue;
      }

      final topics = entry.value as Map<String, dynamic>? ?? {};

      for (final topicEntry in topics.entries) {
        if (_topicMatches(topicEntry.key, topic)) {
          final topicQuestions = topicEntry.value;
          if (topicQuestions is List) {
            for (final q in topicQuestions) {
              if (q is Map<String, dynamic>) {
                questions.add(q);
              }
            }
          }
        }
      }
    }

    // Shuffle and limit
    if (questions.isNotEmpty) {
      questions.shuffle(Random());
      if (questions.length > count) {
        questions = questions.sublist(0, count);
      }
    }

    return questions;
  }

  /// Returns a list of available subjects from the cache.
  Future<List<String>> getAvailableSubjects() async {
    final cache = await _ensureCache();
    if (cache == null) return [];

    final subjects = cache['subjects'] as List<dynamic>? ?? [];
    return subjects
        .map((s) => (s as Map<String, dynamic>)['name']?.toString() ?? '')
        .where((name) => name.isNotEmpty)
        .toList();
  }

  /// Returns available topics for a [subject] and [grade].
  Future<List<String>> getAvailableTopics({
    required String subject,
    String? grade,
  }) async {
    final cache = await _ensureCache();
    if (cache == null) return [];

    final subjects = cache['subjects'] as List<dynamic>? ?? [];
    final subjectData = _findSubject(subjects, subject);
    if (subjectData == null) return [];

    final grades = subjectData['grades'] as Map<String, dynamic>? ?? {};
    final topics = <String>{};

    for (final entry in grades.entries) {
      if (grade != null && grade.isNotEmpty && !_gradeMatches(entry.key, grade)) {
        continue;
      }
      final topicsMap = entry.value as Map<String, dynamic>? ?? {};
      topics.addAll(topicsMap.keys);
    }

    return topics.toList()..sort();
  }

  /// Force-refresh the cache from the server. Returns true on success.
  Future<bool> refreshCache() async {
    try {
      final response = await http
          .get(Uri.parse('$_apiBaseUrl/api/questions'))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _saveToPrefs(response.body);
        _memoryCache = data as Map<String, dynamic>;
        debugPrint('QuestionCache: refreshed ${_countQuestions(data)} questions');
        return true;
      }
    } catch (e) {
      debugPrint('QuestionCache: refresh failed — $e');
    }
    return false;
  }

  /// Returns the DateTime of the last successful sync, or null if never synced.
  Future<DateTime?> lastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_lastSyncKey);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// Whether the cache has any data (in memory or on disk).
  Future<bool> get hasCachedData async {
    if (_memoryCache != null) return true;
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_cacheKey);
  }

  /// Whether the cache is stale (older than [_staleDuration]).
  Future<bool> get isStale async {
    final last = await lastSyncTime();
    if (last == null) return true;
    return DateTime.now().difference(last) > _staleDuration;
  }

  /// Initialise the cache. Call this early (e.g. in main or after login).
  /// Downloads fresh data if the cache is stale or empty.
  Future<void> initialize() async {
    // Load from disk into memory first (fast)
    await _loadFromPrefs();

    // Then refresh in the background if stale
    if (await isStale) {
      // Fire-and-forget; don't block the UI
      refreshCache();
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Make sure we have data in [_memoryCache]. Loads from disk if needed,
  /// fetches from server if nothing is cached.
  Future<Map<String, dynamic>?> _ensureCache() async {
    if (_memoryCache != null) return _memoryCache;

    // Try loading from SharedPreferences
    await _loadFromPrefs();
    if (_memoryCache != null) return _memoryCache;

    // Nothing cached — try fetching from server
    final success = await refreshCache();
    return success ? _memoryCache : null;
  }

  Future<void> _loadFromPrefs() async {
    if (_memoryCache != null) return;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        _memoryCache = jsonDecode(raw) as Map<String, dynamic>;
      } catch (e) {
        debugPrint('QuestionCache: corrupt cache, clearing — $e');
        await prefs.remove(_cacheKey);
      }
    }
  }

  Future<void> _saveToPrefs(String jsonString) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, jsonString);
    await prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Fuzzy match a subject entry by name or id.
  Map<String, dynamic>? _findSubject(List<dynamic> subjects, String query) {
    final q = query.toLowerCase().trim();
    for (final s in subjects) {
      final m = s as Map<String, dynamic>;
      final name = (m['name'] ?? '').toString().toLowerCase();
      final id = (m['id'] ?? '').toString().toLowerCase();
      if (name == q || id == q) return m;
    }
    // Partial match
    for (final s in subjects) {
      final m = s as Map<String, dynamic>;
      final name = (m['name'] ?? '').toString().toLowerCase();
      final id = (m['id'] ?? '').toString().toLowerCase();
      if (name.contains(q) || q.contains(name) || id.contains(q)) return m;
    }
    return null;
  }

  /// Check if a cached grade key matches the student's grade.
  bool _gradeMatches(String cachedGrade, String studentGrade) {
    final a = cachedGrade.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    final b = studentGrade.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    return a == b || a.contains(b) || b.contains(a);
  }

  /// Check if a cached topic key matches the requested topic (partial / fuzzy).
  bool _topicMatches(String cachedTopic, String requestedTopic) {
    final a = cachedTopic.toLowerCase().trim();
    final b = requestedTopic.toLowerCase().trim();
    return a == b || a.contains(b) || b.contains(a);
  }

  int _countQuestions(Map<String, dynamic> data) {
    int count = 0;
    final subjects = data['subjects'] as List<dynamic>? ?? [];
    for (final s in subjects) {
      final grades = (s as Map<String, dynamic>)['grades'] as Map<String, dynamic>? ?? {};
      for (final g in grades.values) {
        final topics = g as Map<String, dynamic>? ?? {};
        for (final t in topics.values) {
          if (t is List) count += t.length;
        }
      }
    }
    return count;
  }
}
