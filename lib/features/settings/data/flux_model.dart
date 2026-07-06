final class FluxModel {
  final String id;
  final String name;
  final String? description;
  final bool isDefault;

  const FluxModel({
    required this.id,
    required this.name,
    this.description,
    this.isDefault = false,
  });

  factory FluxModel.fromJson(Map<String, dynamic> json) {
    return FluxModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      isDefault: json['is_default'] as bool? ?? false,
    );
  }

  @override
  String toString() => 'FluxModel(id: $id, name: $name)';
}
