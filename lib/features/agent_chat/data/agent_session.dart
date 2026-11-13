/// Sessão de chat v2 (`/api/v2/sessions`).
class AgentSession {
  final String id;
  final String title;
  final String channel;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AgentSession({
    required this.id,
    required this.title,
    this.channel = 'app',
    this.createdAt,
    this.updatedAt,
  });

  static AgentSession fromJson(Map<String, dynamic> json) => AgentSession(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? 'Nova conversa',
        channel: json['channel']?.toString() ?? 'app',
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
        updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
      );

  AgentSession copyWith({String? title}) => AgentSession(
        id: id,
        title: title ?? this.title,
        channel: channel,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
