/// Kind de uma categoria financeira.
enum CategoryKind {
  expense,
  income,
  internal,
  uncategorized;

  static CategoryKind fromString(String value) {
    return CategoryKind.values.firstWhere(
      (k) => k.name == value,
      orElse: () => CategoryKind.expense,
    );
  }

  String get labelPt {
    switch (this) {
      case CategoryKind.expense:
        return 'Despesa';
      case CategoryKind.income:
        return 'Receita';
      case CategoryKind.internal:
        return 'Interna';
      case CategoryKind.uncategorized:
        return 'Sem categoria';
    }
  }
}

/// Categoria financeira definida pelo usuário ou sistema.
class Category {
  final int id;
  final String name;
  final CategoryKind kind;
  final bool isSystem;
  final int displayOrder;
  final DateTime? createdAt;

  const Category({
    required this.id,
    required this.name,
    required this.kind,
    required this.isSystem,
    required this.displayOrder,
    this.createdAt,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      kind: CategoryKind.fromString(json['kind'] as String? ?? 'expense'),
      isSystem: json['is_system'] as bool? ?? false,
      displayOrder: json['display_order'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'kind': kind.name,
      'display_order': displayOrder,
    };
  }
}
