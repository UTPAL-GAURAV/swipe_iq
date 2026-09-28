import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const kAllSubjects = ['Java', 'Java Advanced', 'Spring Boot', 'HLD Concepts', 'HLD Scenarios'];

const _kThemeKey = 'theme_mode';
const _kSubjectsKey = 'selected_subjects';

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (_) => throw UnimplementedError('sharedPreferencesProvider not initialized'),
);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final stored = ref.read(sharedPreferencesProvider).getString(_kThemeKey);
    return switch (stored) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  void set(ThemeMode mode) {
    state = mode;
    ref.read(sharedPreferencesProvider).setString(
          _kThemeKey,
          switch (mode) {
            ThemeMode.light => 'light',
            ThemeMode.dark => 'dark',
            _ => 'system',
          },
        );
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class SelectedSubjectsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    final stored =
        ref.read(sharedPreferencesProvider).getStringList(_kSubjectsKey);
    if (stored == null || stored.isEmpty) return Set.from(kAllSubjects);
    return Set.from(stored);
  }

  void toggle(String subject, bool selected) {
    final next = Set<String>.from(state);
    if (selected) {
      next.add(subject);
    } else {
      if (next.length <= 1) return;
      next.remove(subject);
    }
    state = next;
    ref
        .read(sharedPreferencesProvider)
        .setStringList(_kSubjectsKey, next.toList());
  }
}

final selectedSubjectsProvider =
    NotifierProvider<SelectedSubjectsNotifier, Set<String>>(
  SelectedSubjectsNotifier.new,
);
