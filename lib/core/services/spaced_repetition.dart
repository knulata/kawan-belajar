import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

/// A single word card with SM-2 scheduling metadata.
class WordCard {
  final String word;
  final String pinyin;
  final String meaning;
  double easeFactor;
  int interval; // days until next review
  DateTime nextReview;
  int repetitions;

  WordCard({
    required this.word,
    required this.pinyin,
    required this.meaning,
    this.easeFactor = 2.5,
    this.interval = 0,
    DateTime? nextReview,
    this.repetitions = 0,
  }) : nextReview = nextReview ?? DateTime.now();

  /// Whether this card is due for review (nextReview <= now).
  bool get isDue =>
      DateTime.now().isAfter(nextReview) ||
      DateTime.now().isAtSameMomentAs(nextReview);

  Map<String, dynamic> toJson() => {
        'word': word,
        'pinyin': pinyin,
        'meaning': meaning,
        'easeFactor': easeFactor,
        'interval': interval,
        'nextReview': nextReview.toIso8601String(),
        'repetitions': repetitions,
      };

  factory WordCard.fromJson(Map<String, dynamic> json) => WordCard(
        word: json['word'] as String,
        pinyin: json['pinyin'] as String,
        meaning: json['meaning'] as String,
        easeFactor: (json['easeFactor'] as num?)?.toDouble() ?? 2.5,
        interval: json['interval'] as int? ?? 0,
        nextReview: json['nextReview'] != null
            ? DateTime.parse(json['nextReview'] as String)
            : DateTime.now(),
        repetitions: json['repetitions'] as int? ?? 0,
      );
}

/// SM-2 based spaced repetition service for Mandarin dictation words.
///
/// Stores all word history locally via SharedPreferences, keyed per student.
class SpacedRepetitionService {
  static const _storageKeyPrefix = 'sr_words_';

  final String studentId;
  final Map<String, WordCard> _cards = {};
  bool _loaded = false;

  SpacedRepetitionService({required this.studentId});

  String get _storageKey => '$_storageKeyPrefix$studentId';

  /// Load word history from disk. Must be called before other methods.
  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        for (final item in list) {
          final card = WordCard.fromJson(item as Map<String, dynamic>);
          _cards[card.word] = card;
        }
      } catch (_) {
        // Corrupted data — start fresh
      }
    }
    _loaded = true;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _cards.values.map((c) => c.toJson()).toList();
    await prefs.setString(_storageKey, jsonEncode(list));
  }

  /// Record an answer for a word using SM-2 algorithm.
  ///
  /// [quality] ranges from 0 to 5:
  ///   0 = completely wrong
  ///   3 = hard / barely recalled
  ///   4 = good
  ///   5 = easy / perfect
  Future<void> recordAnswer(Map<String, String> wordData, int quality) async {
    await load();
    final word = wordData['word'] ?? '';
    if (word.isEmpty) return;

    // Get or create the card
    var card = _cards[word];
    if (card == null) {
      card = WordCard(
        word: word,
        pinyin: wordData['pinyin'] ?? '',
        meaning: wordData['meaning'] ?? '',
      );
      _cards[word] = card;
    }

    // Clamp quality to 0-5
    final q = quality.clamp(0, 5);

    // SM-2 algorithm
    if (q < 3) {
      // Failed: reset repetitions, review again soon
      card.repetitions = 0;
      card.interval = 0;
      card.nextReview = DateTime.now(); // due immediately next session
    } else {
      // Successful recall
      if (card.repetitions == 0) {
        card.interval = 1;
      } else if (card.repetitions == 1) {
        card.interval = 6;
      } else {
        card.interval = (card.interval * card.easeFactor).round();
      }
      card.repetitions++;
      card.nextReview = DateTime.now().add(Duration(days: card.interval));
    }

    // Update ease factor (never below 1.3)
    card.easeFactor = max(
      1.3,
      card.easeFactor + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02)),
    );

    await _save();
  }

  /// Get all words that are due for review right now.
  Future<List<WordCard>> getDueWords() async {
    await load();
    final due = _cards.values.where((c) => c.isDue).toList();
    // Sort: lowest ease factor first (hardest words first)
    due.sort((a, b) => a.easeFactor.compareTo(b.easeFactor));
    return due;
  }

  /// Get the count of due words without loading full list.
  Future<int> getDueCount() async {
    await load();
    return _cards.values.where((c) => c.isDue).length;
  }

  /// Get new words (not yet in the review system) from a provided word list.
  ///
  /// Returns up to [count] words that haven't been seen before.
  List<Map<String, String>> getNewWords(
    List<Map<String, String>> allWords,
    int count,
  ) {
    final unseen = allWords.where((w) => !_cards.containsKey(w['word'])).toList();
    if (unseen.length <= count) return unseen;
    // Shuffle to keep it interesting
    unseen.shuffle(Random());
    return unseen.sublist(0, count);
  }

  /// Check if a word has been seen before.
  bool hasWord(String word) => _cards.containsKey(word);

  /// Total number of words in the system.
  int get totalWords => _cards.length;
}
