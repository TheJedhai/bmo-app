class CodingSession {
  /// UUID atribuído pelo QwenPaw (usado pelo backend ao proxiar chamadas).
  final String id;
  /// PK em chat_sessions (formato `bmo-<ms>-<salt>`), usada nas rotas REST
  /// do bmo-server (DELETE, PATCH, etc).
  final String sessionId;
  final int projectId;
  final String name;
  final String createdAt;
  final String updatedAt;

  const CodingSession({
    required this.id,
    required this.sessionId,
    required this.projectId,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CodingSession.fromJson(Map<String, dynamic> json) {
    return CodingSession(
      id: json['id'] as String? ?? '',
      sessionId: json['session_id'] as String? ?? '',
      projectId: json['project_id'] as int? ?? 0,
      name: json['title'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': name,
    };
  }

  CodingSession copyWith({
    String? id,
    String? sessionId,
    int? projectId,
    String? name,
    String? createdAt,
    String? updatedAt,
  }) {
    return CodingSession(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      projectId: projectId ?? this.projectId,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
