/// Merchant sem categoria, vindo do endpoint /uncategorized.
class UncategorizedMerchant {
  final String merchantNormalized;
  final int count;
  final double totalAmount;
  final String? exampleTitle;

  const UncategorizedMerchant({
    required this.merchantNormalized,
    required this.count,
    required this.totalAmount,
    this.exampleTitle,
  });

  factory UncategorizedMerchant.fromJson(Map<String, dynamic> json) {
    return UncategorizedMerchant(
      merchantNormalized: json['merchant_normalized'] as String? ?? '',
      count: json['count'] as int? ?? 0,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      exampleTitle: json['example_title'] as String?,
    );
  }
}
