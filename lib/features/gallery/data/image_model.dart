/// Model for an image returned by GET /api/v1/images.
class GalleryImage {
  final int id;
  final String mode; // "txt2img" | "img2img"
  final String status; // "generating" | "done" | "failed"
  final String? prompt;
  final String? model;
  final num? strength; // img2img only
  final DateTime? createdAt;

  const GalleryImage({
    required this.id,
    required this.mode,
    required this.status,
    this.prompt,
    this.model,
    this.strength,
    this.createdAt,
  });

  bool get isGenerating => status == 'generating';
  bool get isDone => status == 'done';
  bool get isFailed => status == 'failed';

  factory GalleryImage.fromJson(Map<String, dynamic> json) {
    return GalleryImage(
      id: _parseInt(json['id'], 0),
      mode: json['mode'] as String? ?? '',
      status: json['status'] as String? ?? '',
      prompt: json['prompt'] as String?,
      model: json['model'] as String?,
      strength: json['strength'] as num?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  static int _parseInt(dynamic value, int fallback) {
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = num.tryParse(value);
      if (parsed != null) return parsed.toInt();
    }
    return fallback;
  }
}
