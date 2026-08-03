class CodingProject {
  final int id;
  final String name;
  final String primaryPath;
  final List<String> extraPaths;
  final String permissionMode;
  final List<String> allowRules;
  final List<String> denyRules;
  final String? knowledge;
  final String createdAt;
  final String updatedAt;

  const CodingProject({
    required this.id,
    required this.name,
    required this.primaryPath,
    required this.extraPaths,
    required this.permissionMode,
    required this.allowRules,
    required this.denyRules,
    this.knowledge,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CodingProject.fromJson(Map<String, dynamic> json) {
    return CodingProject(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      primaryPath: json['primary_path'] as String? ?? '',
      extraPaths: (json['extra_paths'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      permissionMode: json['permission_mode'] as String? ?? 'default',
      allowRules: (json['allow_rules'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      denyRules: (json['deny_rules'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      knowledge: json['knowledge'] as String?,
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'primary_path': primaryPath,
      'extra_paths': extraPaths,
      'permission_mode': permissionMode,
      'allow_rules': allowRules,
      'deny_rules': denyRules,
      if (knowledge != null) 'knowledge': knowledge,
    };
  }

  CodingProject copyWith({
    int? id,
    String? name,
    String? primaryPath,
    List<String>? extraPaths,
    String? permissionMode,
    List<String>? allowRules,
    List<String>? denyRules,
    String? knowledge,
    String? createdAt,
    String? updatedAt,
  }) {
    return CodingProject(
      id: id ?? this.id,
      name: name ?? this.name,
      primaryPath: primaryPath ?? this.primaryPath,
      extraPaths: extraPaths ?? this.extraPaths,
      permissionMode: permissionMode ?? this.permissionMode,
      allowRules: allowRules ?? this.allowRules,
      denyRules: denyRules ?? this.denyRules,
      knowledge: knowledge ?? this.knowledge,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
