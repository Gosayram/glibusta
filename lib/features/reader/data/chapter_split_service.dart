import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chapter_split_rule.dart';

const _key = 'chapter_split_rules';

class ChapterSplitService {
  ChapterSplitService._();
  static final instance = ChapterSplitService._();

  List<ChapterSplitRule> _rules = List.from(ChapterSplitRule.presets);
  bool _loaded = false;

  List<ChapterSplitRule> get rules => List.unmodifiable(_rules);

  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_key);
      if (json != null) {
        final list = jsonDecode(json) as List;
        _rules = list.map((e) => ChapterSplitRule.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    _loaded = true;
  }

  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(_rules.map((r) => r.toJson()).toList());
      await prefs.setString(_key, json);
    } catch (_) {}
  }

  void addRule(ChapterSplitRule rule) {
    _rules.add(rule);
    save();
  }

  void updateRule(ChapterSplitRule rule) {
    final index = _rules.indexWhere((r) => r.id == rule.id);
    if (index >= 0) {
      _rules[index] = rule;
      save();
    }
  }

  void deleteRule(String id) {
    _rules.removeWhere((r) => r.id == id && !r.isPreset);
    save();
  }

  ChapterSplitRule? detectPattern(String text) {
    final lines = text.split('\n');
    final sampleSize = lines.length < 100 ? lines.length : 100;
    final scores = <String, int>{};

    for (var i = 0; i < sampleSize; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      for (final rule in _rules) {
        if (rule.matchesLine(line)) {
          scores[rule.id] = (scores[rule.id] ?? 0) + 1;
        }
      }
    }

    if (scores.isEmpty) return null;

    final bestEntry = scores.entries.reduce((a, b) => a.value > b.value ? a : b);
    if (bestEntry.value < 2) return null;

    return _rules.firstWhere((r) => r.id == bestEntry.key);
  }

  List<String> splitText(String text, ChapterSplitRule rule) {
    final lines = text.split('\n');
    final chapters = <String>[];
    final currentChapter = StringBuffer();

    for (final line in lines) {
      if (rule.matchesLine(line.trim()) && currentChapter.isNotEmpty) {
        chapters.add(currentChapter.toString());
        currentChapter.clear();
      }
      currentChapter.writeln(line);
    }

    if (currentChapter.isNotEmpty) {
      chapters.add(currentChapter.toString());
    }

    return chapters;
  }
}

final chapterSplitServiceProvider = Provider<ChapterSplitService>((ref) {
  return ChapterSplitService.instance;
});
