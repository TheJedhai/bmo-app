final class Scene {
  final int id;
  final String name;

  const Scene({required this.id, required this.name});

  factory Scene.fromJson(Map<String, dynamic> json) {
    return Scene(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
    );
  }

  @override
  String toString() => 'Scene(id=$id, name="$name")';
}
