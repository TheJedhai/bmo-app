/// Fatura (aberta ou fechada) do cartão de crédito.
class BillInfo {
  final double totalAmount;
  final String? dueDate;
  final String? source;
  final String? importedAt;
  final int? itemCount;

  const BillInfo({
    required this.totalAmount,
    this.dueDate,
    this.source,
    this.importedAt,
    this.itemCount,
  });

  factory BillInfo.fromJson(Map<String, dynamic> json) {
    return BillInfo(
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      dueDate: json['due_date'] as String?,
      source: json['source'] as String?,
      importedAt: json['imported_at'] as String?,
      itemCount: json['item_count'] as int?,
    );
  }
}

/// Sumarização por categoria.
class CategorySummary {
  final String category;
  final int? categoryId;
  final double total;
  final int count;

  const CategorySummary({
    required this.category,
    this.categoryId,
    required this.total,
    required this.count,
  });

  factory CategorySummary.fromJson(Map<String, dynamic> json) {
    return CategorySummary(
      category: json['category'] as String? ?? 'Sem categoria',
      categoryId: json['category_id'] as int?,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      count: json['count'] as int? ?? 0,
    );
  }
}

/// Sumarização por conta.
class AccountSummary {
  final String accountId;
  final String accountName;
  final String accountType;
  final double total;

  const AccountSummary({
    required this.accountId,
    required this.accountName,
    required this.accountType,
    required this.total,
  });

  factory AccountSummary.fromJson(Map<String, dynamic> json) {
    return AccountSummary(
      accountId: json['account_id'] as String? ?? '',
      accountName: json['name'] as String? ?? '',
      accountType: json['account_type'] as String? ?? 'BANK',
      total: (json['expenses'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Resumo financeiro mensal.
class FinanceSummary {
  final double checkingBalance;
  final double totalSpent;
  final double totalIncome;
  final double net;
  final double totalCreditDebt;
  final BillInfo? lastClosedBill;
  final BillInfo? openBill;
  final double netPosition;
  final String? creditSource;
  final List<CategorySummary> byCategory;
  final List<AccountSummary> byAccount;

  const FinanceSummary({
    required this.checkingBalance,
    required this.totalSpent,
    required this.totalIncome,
    required this.net,
    required this.totalCreditDebt,
    this.lastClosedBill,
    this.openBill,
    required this.netPosition,
    this.creditSource,
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
      checkingBalance:
          (json['checking_balance'] as num?)?.toDouble() ?? 0.0,
      totalSpent: (json['expenses'] as num?)?.toDouble() ?? 0.0,
      totalIncome: (json['income'] as num?)?.toDouble() ?? 0.0,
      net: (json['net'] as num?)?.toDouble() ?? 0.0,
      totalCreditDebt:
          (json['total_credit_debt'] as num?)?.toDouble() ?? 0.0,
      lastClosedBill: json['last_closed_bill'] != null
          ? BillInfo.fromJson(
              json['last_closed_bill'] as Map<String, dynamic>)
          : null,
      openBill: json['open_bill'] != null
          ? BillInfo.fromJson(json['open_bill'] as Map<String, dynamic>)
          : null,
      netPosition:
          (json['net_position'] as num?)?.toDouble() ?? 0.0,
      creditSource: json['credit_source'] as String?,
      byCategory: byCategory,
      byAccount: byAccount,
    );
  }
}
