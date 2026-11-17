import 'dart:convert';

import 'package:http/http.dart' as http;

/// Erro do bmo-server no formato `{"error", "message"}`.
class RoutinesApiException implements Exception {
  final int statusCode;
  final String errorCode;
  final String message;

  const RoutinesApiException(this.statusCode, this.errorCode, this.message);

  @override
  String toString() => 'RoutinesApiException($statusCode $errorCode): $message';
}

/// Estado de presença do contrato (`GET/PUT /api/v1/notifications/presence`).
enum PresenceMode {
  emCasa('em_casa', 'em casa'),
  fora('fora', 'fora'),
  vozSilenciada('voz_silenciada', 'voz silenciada'),
  noite('noite', 'noite');

  const PresenceMode(this.wire, this.label);

  /// Valor do contrato (`state`).
  final String wire;

  /// Texto da interface (pt-BR) — não vem do servidor.
  final String label;

  static PresenceMode? fromWire(Object? value) {
    for (final mode in PresenceMode.values) {
      if (mode.wire == value) return mode;
    }
    return null;
  }
}

class Presence {
  final PresenceMode mode;

  /// Fim do estado, quando o servidor deu prazo.
  final DateTime? until;

  const Presence({required this.mode, this.until});

  factory Presence.fromJson(Map<String, dynamic> json) => Presence(
    mode: PresenceMode.fromWire(json['state']) ?? PresenceMode.emCasa,
    until: DateTime.tryParse(json['until']?.toString() ?? ''),
  );
}

/// Notificação do `/api/v1/notifications`.
class AppNotification {
  final int id;
  final String level;
  final String title;
  final String body;
  final String source;
  final String? channel;
  final DateTime? createdAt;
  final DateTime? deliveredAt;
  final DateTime? readAt;

  const AppNotification({
    required this.id,
    required this.level,
    required this.title,
    required this.body,
    required this.source,
    this.channel,
    this.createdAt,
    this.deliveredAt,
    this.readAt,
  });

  /// Segurada ainda não entregue (noite): fica destacada na lista.
  bool get held => channel == 'segurada' && deliveredAt == null;

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] is num ? (json['id'] as num).toInt() : 0,
        level: json['level']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        body: json['body']?.toString() ?? '',
        source: json['source']?.toString() ?? '',
        channel: json['channel']?.toString(),
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
        deliveredAt: DateTime.tryParse(json['delivered_at']?.toString() ?? ''),
        readAt: DateTime.tryParse(json['read_at']?.toString() ?? ''),
      );
}

/// `/api/v1/routines/config` — horários, tempo e seções do bom dia.
class RoutineSettings {
  final String dayRoll;
  final String quietEnd;
  final double weatherLat;
  final double weatherLon;
  final String weatherPlace;

  /// `sections` do servidor: chave do contrato → ligada/desligada.
  final Map<String, bool> sections;

  const RoutineSettings({
    required this.dayRoll,
    required this.quietEnd,
    required this.weatherLat,
    required this.weatherLon,
    required this.weatherPlace,
    required this.sections,
  });

  factory RoutineSettings.fromJson(Map<String, dynamic> json) {
    final rawSections = json['sections'];
    return RoutineSettings(
      dayRoll: json['day_roll']?.toString() ?? '04:00',
      quietEnd: json['quiet_end']?.toString() ?? '10:00',
      weatherLat: _toDouble(json['weather_lat']),
      weatherLon: _toDouble(json['weather_lon']),
      weatherPlace: json['weather_place']?.toString() ?? '',
      sections: {
        if (rawSections is Map)
          for (final entry in rawSections.entries)
            entry.key.toString(): entry.value == true,
      },
    );
  }

  static double _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

/// Item do `GET /api/v1/triggers`.
class RoutineTrigger {
  final String key;
  final String type;

  /// Descrição do servidor — exibida como veio, sem reinterpretação.
  final String description;
  final String? schedule;
  final List<String> phrases;
  final String? event;
  final bool enabled;

  const RoutineTrigger({
    required this.key,
    required this.type,
    required this.description,
    this.schedule,
    this.phrases = const [],
    this.event,
    required this.enabled,
  });

  RoutineTrigger copyWith({bool? enabled}) => RoutineTrigger(
    key: key,
    type: type,
    description: description,
    schedule: schedule,
    phrases: phrases,
    event: event,
    enabled: enabled ?? this.enabled,
  );

  factory RoutineTrigger.fromJson(Map<String, dynamic> json) => RoutineTrigger(
    key: json['key']?.toString() ?? '',
    type: json['type']?.toString() ?? '',
    description: json['description']?.toString() ?? '',
    schedule: json['schedule']?.toString(),
    phrases: [
      if (json['phrases'] is List)
        for (final phrase in json['phrases'] as List) phrase.toString(),
    ],
    event: json['event']?.toString(),
    enabled: json['enabled'] == true,
  );
}

class RoutinesClient {
  final http.Client _client;
  final String _baseUrl;

  RoutinesClient({required http.Client client, required String baseUrl})
    : _client = client,
      _baseUrl = baseUrl;

  // ── presença ─────────────────────────────────────────────────────────────

  Future<Presence> getPresence() async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/api/v1/notifications/presence'),
    );
    return Presence.fromJson(_decode(response) as Map<String, dynamic>);
  }

  Future<Presence> setPresence(PresenceMode mode, {DateTime? until}) async {
    final response = await _client.put(
      Uri.parse('$_baseUrl/api/v1/notifications/presence'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'state': mode.wire,
        if (until != null) 'until': until.toUtc().toIso8601String(),
      }),
    );
    return Presence.fromJson(_decode(response) as Map<String, dynamic>);
  }

  // ── notificações ─────────────────────────────────────────────────────────

  Future<List<AppNotification>> listNotifications({int limit = 50}) async {
    final uri = Uri.parse(
      '$_baseUrl/api/v1/notifications',
    ).replace(queryParameters: {'limit': '$limit'});
    final decoded = _decode(await _client.get(uri));
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map(
          (json) => AppNotification.fromJson(Map<String, dynamic>.from(json)),
        )
        .toList();
  }

  // ── configuração das rotinas ─────────────────────────────────────────────

  Future<RoutineSettings> getRoutineSettings() async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/api/v1/routines/config'),
    );
    return RoutineSettings.fromJson(_decode(response) as Map<String, dynamic>);
  }

  Future<RoutineSettings> patchRoutineSettings(
    Map<String, dynamic> patch,
  ) async {
    final response = await _client.patch(
      Uri.parse('$_baseUrl/api/v1/routines/config'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(patch),
    );
    return RoutineSettings.fromJson(_decode(response) as Map<String, dynamic>);
  }

  // ── gatilhos ─────────────────────────────────────────────────────────────

  Future<List<RoutineTrigger>> listTriggers() async {
    final decoded = _decode(
      await _client.get(Uri.parse('$_baseUrl/api/v1/triggers')),
    );
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((json) => RoutineTrigger.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  Future<void> setTriggerEnabled(String key, bool enabled) async {
    final response = await _client.patch(
      Uri.parse('$_baseUrl/api/v1/triggers/$key'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'enabled': enabled}),
    );
    _decode(response);
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  dynamic _decode(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }
    var errorCode = 'error';
    var message = response.body;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        errorCode = decoded['error']?.toString() ?? errorCode;
        message = decoded['message']?.toString() ?? message;
      }
    } catch (_) {
      // Corpo não-JSON: usa o texto bruto.
    }
    throw RoutinesApiException(response.statusCode, errorCode, message);
  }
}
