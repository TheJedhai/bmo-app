/// Sessão de chat v2 (`/api/v2/sessions`).
class AgentSession {
  final String id;
  final String title;
  final String channel;

  /// Turno concluído que o usuário ainda não leu (fonte: servidor).
  final bool unread;

  /// `chat` = conversa comum; `daily` = conversa do dia.
  final String kind;

  /// Data local da virada (`daily` só).
  final DateTime? day;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AgentSession({
    required this.id,
    required this.title,
    this.channel = 'app',
    this.unread = false,
    this.kind = 'chat',
    this.day,
    this.createdAt,
    this.updatedAt,
  });

  bool get isDaily => kind == 'daily';

  static AgentSession fromJson(Map<String, dynamic> json) => AgentSession(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? 'Nova conversa',
        channel: json['channel']?.toString() ?? 'app',
        unread: json['unread'] == true,
        kind: json['kind']?.toString() ?? 'chat',
        day: DateTime.tryParse(json['day']?.toString() ?? ''),
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
        updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
      );

  AgentSession copyWith({String? title, bool? unread}) => AgentSession(
        id: id,
        title: title ?? this.title,
        channel: channel,
        unread: unread ?? this.unread,
        kind: kind,
        day: day,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
