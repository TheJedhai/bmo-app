/// Representa uma conversa persistida no QwenPaw.
///
/// IMPORTANTE: tem dois IDs distintos:
/// - [uuid]      = campo `id` da API. Usado em GET/PUT/DELETE /api/chats/{uuid}.
/// - [sessionId] = campo `session_id`. Usado no POST /api/chat (envio).
final class Conversation {
  final String uuid;
  final String sessionId;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Conversation({
    required this.uuid,
    required this.sessionId,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      uuid: json['id'] as String? ?? '',
      sessionId: json['session_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
    );
  }

  Conversation copyWith({
    String? name,
    DateTime? updatedAt,
  }) {
    return Conversation(
      uuid: uuid,
      sessionId: sessionId,
      name: name ?? this.name,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'Conversation(uuid=$uuid, sessionId=$sessionId, name="$name")';
}

DateTime _parseDate(dynamic value) {
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value) ?? DateTime.now();
  }
  if (value is num) {
    // Trata como timestamp em segundos (Unix epoch).
    return DateTime.fromMillisecondsSinceEpoch(
      (value * 1000).toInt(),
      isUtc: true,
    );
  }
  return DateTime.now();
}
