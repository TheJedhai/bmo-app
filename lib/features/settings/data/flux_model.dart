final class FluxModel {
  final String name;
  final String? description;
  final bool isDefault;

  const FluxModel({
    required this.name,
    this.description,
    this.isDefault = false,
  });

  factory FluxModel.fromJson(Map<String, dynamic> json) {
    return FluxModel(
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      isDefault: json['is_default'] as bool? ?? false,
    );
  }

  @override
  String toString() => 'FluxModel(name: $name)';
}
