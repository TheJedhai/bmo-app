import 'transaction.dart';

/// Revisão de duplicata — duas ou mais transações candidatas a serem a mesma compra.
class DedupReview {
  final int id;
  final String status;
  final List<Transaction> transactions;

  const DedupReview({
    required this.id,
    required this.status,
    required this.transactions,
  });

  factory DedupReview.fromJson(Map<String, dynamic> json) {
    final txs = (json['transactions'] as List<dynamic>?)
            ?.map((e) => Transaction.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const <Transaction>[];
    return DedupReview(
      id: json['id'] as int? ?? 0,
      status: json['status'] as String? ?? 'pending',
      transactions: txs,
    );
  }

  /// Primeira transação (conveniência para UI lado a lado).
  Transaction? get transactionA =>
      transactions.isNotEmpty ? transactions[0] : null;

  /// Segunda transação (conveniência para UI lado a lado).
  Transaction? get transactionB =>
      transactions.length > 1 ? transactions[1] : null;
}
