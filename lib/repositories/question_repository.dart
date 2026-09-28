import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import '../models/question.dart';

class QuestionRepository {
  static const _subjectFiles = {
    'Java': 'assets/questions/java.json',
    'Java Advanced': 'assets/questions/java_advanced.json',
    'Spring Boot': 'assets/questions/spring_boot.json',
    'HLD Concepts': 'assets/questions/hld_concepts.json',
    'HLD Scenarios': 'assets/questions/hld_scenarios.json',
  };

  final _random = Random();
  final Map<String, List<Question>> _bySubject = {};

  Future<void> _ensureLoaded() async {
    if (_bySubject.isNotEmpty) return;
    for (final entry in _subjectFiles.entries) {
      final raw = await rootBundle.loadString(entry.value);
      final list = jsonDecode(raw) as List;
      _bySubject[entry.key] =
          list.map((e) => Question.fromJson(e as Map<String, dynamic>)).toList();
    }
  }

  Future<Question> randomQuestion({required Set<String> subjects}) async {
    await _ensureLoaded();
    final active = subjects.isEmpty ? _subjectFiles.keys.toSet() : subjects;
    final pool = _bySubject.entries
        .where((e) => active.contains(e.key))
        .expand((e) => e.value)
        .toList();
    return pool[_random.nextInt(pool.length)];
  }

  // Adding a new subject: add entry to _subjectFiles and its JSON to assets/.
}
