/// Model for a parsed ```bmo:rich code-fence envelope.
///
/// Envelope shape (from the BMO backend):
/// ```json
/// {"v":1,"type":"image","block_id":"image-20","payload":{"image_id":20},"mutable":true}
/// ```
///
/// [fromJson] is lenient — missing or mistyped fields get safe defaults so a
/// malformed block never crashes the parser or the UI.
class BmoRichBlock {
  final int v;
  final String type;
  final String blockId;
  final Map<String, dynamic> payload;
  final bool mutable;

  const BmoRichBlock({
    required this.v,
    required this.type,
    required this.blockId,
    required this.payload,
    required this.mutable,
  });

  factory BmoRichBlock.fromJson(Map<String, dynamic> json) {
    return BmoRichBlock(
      v: _parseInt(json['v'], 1),
      type: json['type'] is String ? json['type'] as String : '',
      blockId: json['block_id'] is String ? json['block_id'] as String : '',
      payload: json['payload'] is Map<String, dynamic>
          ? json['payload'] as Map<String, dynamic>
          : const {},
      mutable: json['mutable'] is bool ? json['mutable'] as bool : false,
    );
  }

  /// Lenient int parser — tries [num], then [String], falls back to [fallback].
  static int _parseInt(dynamic value, int fallback) {
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = num.tryParse(value);
      if (parsed != null) return parsed.toInt();
    }
    return fallback;
  }
}
