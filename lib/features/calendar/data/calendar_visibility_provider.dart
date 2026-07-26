import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/identity/identity_provider.dart';
import '../../../../core/identity/identity_state.dart';

/// Keys for shared_preferences storage.
const _kVisibilityPrefix = 'hidden_calendars_';

/// Manages per-user calendar visibility toggles.
///
/// Hidden calendar IDs are persisted in shared_preferences keyed by userId.
/// New calendars default to visible (not in the hidden set).
/// Storage failures are caught silently — the app works without persistence.
class CalendarVisibilityNotifier extends StateNotifier<Set<int>> {
  final Ref _ref;

  CalendarVisibilityNotifier(this._ref) : super(const {}) {
    _load();
  }

  bool isVisible(int calendarId) => !state.contains(calendarId);

  void toggle(int calendarId) {
    final updated = Set<int>.from(state);
    if (updated.contains(calendarId)) {
      updated.remove(calendarId);
    } else {
      updated.add(calendarId);
    }
    state = updated;
    _save();
  }

  void _load() {
    final prefs = _ref.read(sharedPreferencesProvider);
    if (prefs == null) return;
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) return;
    try {
      final raw = prefs.getString('$_kVisibilityPrefix$userId');
      if (raw != null) {
        final list = jsonDecode(raw) as List<dynamic>;
        state = list.map((e) => (e as num).toInt()).toSet();
      }
    } catch (e) {
      debugPrint('CalendarVisibility: load failed: $e');
    }
  }

  void _save() {
    final prefs = _ref.read(sharedPreferencesProvider);
    if (prefs == null) return;
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) return;
    try {
      prefs.setString(
        '$_kVisibilityPrefix$userId',
        jsonEncode(state.toList()),
      );
    } catch (e) {
      debugPrint('CalendarVisibility: save failed: $e');
    }
  }
}

final calendarVisibilityProvider =
    StateNotifierProvider<CalendarVisibilityNotifier, Set<int>>(
  (ref) => CalendarVisibilityNotifier(ref),
);
