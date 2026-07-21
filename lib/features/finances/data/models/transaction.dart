import 'credit_card_metadata.dart';

/// Transação financeira (débito, crédito, cartão, etc.).
class Transaction {
  final String id;
  final String description;
  final String category;
  final double amount;
  final DateTime date;
  final String status;
  final String accountId;
  final String? transactionType;
  final CreditCardMetadata? creditCardMetadata;

  const Transaction({
    required this.id,
    required this.description,
    required this.category,
    required this.amount,
    required this.date,
    required this.status,
    required this.accountId,
    this.transactionType,
    this.creditCardMetadata,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'other',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      date: DateTime.parse(json['date'] as String),
      status: json['status'] as String? ?? 'posted',
      accountId: json['account_id'] as String? ?? '',
      transactionType: json['type'] as String?,
      creditCardMetadata: json['credit_card_metadata'] != null
          ? CreditCardMetadata.fromJson(
              json['credit_card_metadata'] as Map<String, dynamic>)
          : null,
    );
  }

  bool get isPending => status == 'PENDING' || status == 'pending';

  /// Valor de exibição com sinal interpretado.
  ///
  /// BANK_CREDIT = entrada (positivo), demais tipos = saída (negativo).
  /// Cartão de crédito: valor positivo = gasto (negativo na exibição),
  /// valor negativo = estorno/crédito (positivo na exibição).
  double get displayAmount {
    if (transactionType == 'BANK_CREDIT') {
      return amount.abs();
    }
    return -amount.abs();
  }

  /// Se o valor deve ser exibido como positivo (verde).
  bool get isDisplayPositive => displayAmount >= 0;
}
