/// Conta financeira (conta-corrente, poupança, cartão de crédito, etc.).
class Account {
  final String id;
  final String name;
  final String type;
  final double balance;
  final DateTime? updatedAt;

  const Account({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
    this.updatedAt,
  });

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['account_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      type: json['account_type'] as String? ?? 'BANK',
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      updatedAt: json['balance_updated_at'] != null
          ? DateTime.tryParse(json['balance_updated_at'] as String)
          : null,
    );
  }

  String get typeLabel {
    switch (type) {
      case 'CREDIT':
        return 'Cartão de crédito';
      case 'BANK':
        return 'Conta corrente';
      case 'SAVINGS':
        return 'Poupança';
      case 'INVESTMENT':
        return 'Investimento';
      default:
        return type;
    }
  }
}
