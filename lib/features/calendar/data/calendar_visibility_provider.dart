import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/identity/identity_provider.dart';
import '../../../../core/identity/identity_state.dart';
import 'models/calendar_event.dart';

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

/// Shared filter: removes events whose calendar is hidden.
/// Use this everywhere — no inline copies.
List<CalendarEvent> filterVisibleEvents(
  List<CalendarEvent> events,
  Set<int> hiddenCalendarIds,
) {
  return events
      .where((e) => !hiddenCalendarIds.contains(e.calendarId))
      .toList();
}

// ============================================================
// Missions visibility
// ============================================================

const _kShowMissionsKey = 'show_missions_in_calendar_';

/// Manages the "Missões" toggle in the calendar filter.
///
/// Persisted in shared_preferences per user. Defaults to true (shown).
class MissionsCalendarVisibilityNotifier extends StateNotifier<bool> {
  final Ref _ref;

  MissionsCalendarVisibilityNotifier(this._ref) : super(true) {
    _load();
  }

  void toggle() {
    state = !state;
    _save();
  }

  void _load() {
    final prefs = _ref.read(sharedPreferencesProvider);
    if (prefs == null) return;
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) return;
    try {
      state = prefs.getBool('$_kShowMissionsKey$userId') ?? true;
    } catch (e) {
      debugPrint('MissionsVisibility: load failed: $e');
    }
  }

  void _save() {
    final prefs = _ref.read(sharedPreferencesProvider);
    if (prefs == null) return;
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) return;
    try {
      prefs.setBool('$_kShowMissionsKey$userId', state);
    } catch (e) {
      debugPrint('MissionsVisibility: save failed: $e');
    }
  }
}

final missionsCalendarVisibilityProvider =
    StateNotifierProvider<MissionsCalendarVisibilityNotifier, bool>(
  (ref) => MissionsCalendarVisibilityNotifier(ref),
);
