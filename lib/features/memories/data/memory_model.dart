final class Memory {
  final int id;
  final String content;
  final String source;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Memory({
    required this.id,
    required this.content,
    required this.source,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Memory.fromJson(Map<String, dynamic> json) {
    return Memory(
      id: json['id'] as int? ?? 0,
      content: json['content'] as String? ?? '',
      source: json['source'] as String? ?? 'manual',
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'source': source,
      'created_at': _formatDateTime(createdAt),
      'updated_at': _formatDateTime(updatedAt),
    };
  }

  @override
  String toString() =>
      'Memory(id=$id, source="$source", content="${content.length > 40 ? '${content.substring(0, 40)}...' : content}")';
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

String _formatDateTime(DateTime dt) => dt.toUtc().toIso8601String();
