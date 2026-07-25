final class Calendar {
  final int id;
  final String name;
  final String color; // #RRGGBB
  final String type; // "personal" | "shared"
  final bool isDefault;

  const Calendar({
    required this.id,
    required this.name,
    required this.color,
    required this.type,
    this.isDefault = false,
  });

  factory Calendar.fromJson(Map<String, dynamic> json) {
    return Calendar(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      color: json['color'] as String? ?? '#8BC9A3',
      type: json['type'] as String? ?? 'personal',
      isDefault: json['is_default'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color': color,
        'type': type,
        'is_default': isDefault,
      };

  @override
  String toString() => 'Calendar(id=$id, name="$name", type=$type)';
}
