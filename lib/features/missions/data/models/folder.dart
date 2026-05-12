final class Folder {
  final int id;
  final String name;
  final int sortOrder;
  final bool isDefault;
  final DateTime createdAt;

  const Folder({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.isDefault,
    required this.createdAt,
  });

  factory Folder.fromJson(Map<String, dynamic> json) {
    return Folder(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      sortOrder: json['sort_order'] as int? ?? 0,
      isDefault: json['is_default'] as bool? ?? false,
      createdAt: _parseDateTime(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'sort_order': sortOrder,
      'is_default': isDefault,
      'created_at': _formatDateTime(createdAt),
    };
  }

  @override
  String toString() => 'Folder(id=$id, name="$name")';
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
