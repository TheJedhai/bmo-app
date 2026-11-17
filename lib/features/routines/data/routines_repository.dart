import 'routines_client.dart';

/// Ponto único das chamadas HTTP de rotinas/avisos.
class RoutinesRepository {
  final RoutinesClient _client;

  RoutinesRepository(this._client);

  Future<Presence> getPresence() => _client.getPresence();

  Future<Presence> setPresence(PresenceMode mode, {DateTime? until}) =>
      _client.setPresence(mode, until: until);

  Future<NotificationsPage> listNotifications({int limit = 50}) =>
      _client.listNotifications(limit: limit);

  Future<void> markNotificationsRead(List<int> ids) =>
      _client.markNotificationsRead(ids);

  Future<RoutineSettings> getRoutineSettings() => _client.getRoutineSettings();

  Future<RoutineSettings> patchRoutineSettings(Map<String, dynamic> patch) =>
      _client.patchRoutineSettings(patch);

  Future<List<RoutineTrigger>> listTriggers() => _client.listTriggers();

  Future<void> setTriggerEnabled(String key, bool enabled) =>
      _client.setTriggerEnabled(key, enabled);
}
