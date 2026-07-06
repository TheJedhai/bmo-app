final class FluxModel {
  final String id;
  final String name;
  final String? description;

  const FluxModel({
    required this.id,
    required this.name,
    this.description,
  });

  factory FluxModel.fromJson(Map<String, dynamic> json) {
    return FluxModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
    );
  }

  @override
  String toString() => 'FluxModel(id: $id, name: $name)';
}
