/// Sessão de chat v2 (`/api/v2/sessions`).
class AgentSession {
  final String id;
  final String title;
  final String channel;

  /// Turno concluído que o usuário ainda não leu (fonte: servidor).
  final bool unread;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AgentSession({
    required this.id,
    required this.title,
    this.channel = 'app',
    this.unread = false,
    this.createdAt,
    this.updatedAt,
  });

  static AgentSession fromJson(Map<String, dynamic> json) => AgentSession(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? 'Nova conversa',
        channel: json['channel']?.toString() ?? 'app',
        unread: json['unread'] == true,
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
        updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
      );

  AgentSession copyWith({String? title, bool? unread}) => AgentSession(
        id: id,
        title: title ?? this.title,
        channel: channel,
        unread: unread ?? this.unread,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
