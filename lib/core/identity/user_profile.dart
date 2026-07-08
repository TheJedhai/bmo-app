/// Perfil de usuário retornado por GET /api/v1/users e GET /api/v1/me.
///
/// Sem autenticação — identidade de navegação apenas. O servidor usa o
/// header X-User-Id para associar conversas, preferências e features.
class UserProfile {
  final String id;
  final String name;

  const UserProfile({required this.id, required this.name});

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      name: json['name'] as String? ?? json['id'] as String,
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  /// Inicial do nome para avatar (cai pra '?' se nome vazio).
  String get initial {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed[0].toUpperCase();
  }

  @override
  bool operator ==(Object other) =>
      other is UserProfile && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'UserProfile(id: $id, name: $name)';
}
