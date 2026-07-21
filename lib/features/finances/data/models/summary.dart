/// Sumarização por categoria.
class CategorySummary {
  final String category;
  final double total;
  final int count;

  const CategorySummary({
    required this.category,
    required this.total,
    required this.count,
  });

  factory CategorySummary.fromJson(Map<String, dynamic> json) {
    return CategorySummary(
      category: json['category'] as String? ?? 'other',
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      count: json['count'] as int? ?? 0,
    );
  }
}

/// Sumarização por conta.
class AccountSummary {
  final String accountName;
  final double total;

  const AccountSummary({
    required this.accountName,
    required this.total,
  });

  factory AccountSummary.fromJson(Map<String, dynamic> json) {
    return AccountSummary(
      accountName: json['name'] as String? ?? '',
      total: (json['expenses'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Resumo financeiro mensal.
class FinanceSummary {
  final double totalSpent;
  final double totalIncome;
  final double net;
  final List<CategorySummary> byCategory;
  final List<AccountSummary> byAccount;

  const FinanceSummary({
    required this.totalSpent,
    required this.totalIncome,
    required this.net,
    required this.byCategory,
    required this.byAccount,
  });

  factory FinanceSummary.fromJson(Map<String, dynamic> json) {
    final byCategory = (json['by_category'] as List<dynamic>?)
            ?.map((e) => CategorySummary.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const <CategorySummary>[];
    final byAccount = (json['by_account'] as List<dynamic>?)
            ?.map((e) => AccountSummary.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const <AccountSummary>[];
    return FinanceSummary(
      totalSpent: (json['expenses'] as num?)?.toDouble() ?? 0.0,
      totalIncome: (json['income'] as num?)?.toDouble() ?? 0.0,
      net: (json['net'] as num?)?.toDouble() ?? 0.0,
      byCategory: byCategory,
      byAccount: byAccount,
    );
  }
}
