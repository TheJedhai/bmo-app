/// Metadados de parcela de cartão de crédito.
class CreditCardMetadata {
  final int installment;
  final int totalInstallments;

  const CreditCardMetadata({
    required this.installment,
    required this.totalInstallments,
  });

  factory CreditCardMetadata.fromJson(Map<String, dynamic> json) {
    return CreditCardMetadata(
      installment: json['installment_number'] as int? ?? 1,
      totalInstallments: json['total_installments'] as int? ?? 1,
    );
  }

  String get label => '$installment/$totalInstallments';
  bool get isInstallment => totalInstallments > 1;
}
