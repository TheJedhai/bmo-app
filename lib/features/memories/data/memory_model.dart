/// Escopo de uma memória, como o servidor expõe na listagem:
///
/// - `personal` — só do usuário (`userId` preenchido);
/// - `house` — do casal (`userId` nulo);
/// - `all` — os dois (só filtro de listagem, nunca vem no objeto).
enum MemoryScope {
  personal('personal', 'Pessoal'),
  house('house', 'Da casa'),
  all('all', 'Todas');

  const MemoryScope(this.wire, this.label);

  /// Valor aceito por `GET /api/v1/memories?scope=`.
  final String wire;

  /// Rótulo pt-BR para chips/filtros.
  final String label;

  /// Escopo de um objeto vindo do servidor (`personal` ou `house`).
  static MemoryScope? of(Memory memory) =>
      memory.userId == null ? MemoryScope.house : MemoryScope.personal;
}

final class Memory {
  final int id;
  final String content;
  final String source;

  /// Dono da memória pessoal; `null` = memória do casal.
  final int? userId;

  /// Relevância (só vem da busca semântica em `/memories/search`).
  final double? score;

  final DateTime createdAt;
  final DateTime updatedAt;

  const Memory({
    required this.id,
    required this.content,
    required this.source,
    this.userId,
    this.score,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isPersonal => userId != null;

  factory Memory.fromJson(Map<String, dynamic> json) {
    final rawUserId = json['userId'] ?? json['user_id'];
    return Memory(
      id: _parseInt(json['id']) ?? 0,
      content: json['content'] as String? ?? '',
      source: json['source'] as String? ?? 'manual',
      userId: _parseInt(rawUserId),
      score: _parseDouble(json['score']),
      createdAt: _parseDateTime(json['createdAt'] ?? json['created_at']),
      updatedAt: _parseDateTime(json['updatedAt'] ?? json['updated_at']),
    );
  }

  @override
  String toString() =>
      'Memory(id=$id, source="$source", personal=$isPersonal, content="${content.length > 40 ? '${content.substring(0, 40)}...' : content}")';
}

int? _parseInt(dynamic value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

double? _parseDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

DateTime _parseDateTime(dynamic value) {
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value) ?? DateTime.now();
  }
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(
      (value * 1000).toInt(),
      isUtc: true,
    );
  }
  return DateTime.now();
}
