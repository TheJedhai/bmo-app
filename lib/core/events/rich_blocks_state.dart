/// The live status of a rich block, driven by `rich.update` SSE events.
enum RichBlockStatus {
  /// Content is being generated (progress 0–100 via [RichBlockState.progress]).
  generating,

  /// Content generation completed successfully.
  done,

  /// Content generation failed; see [RichBlockState.error].
  failed,
}

/// Immutable snapshot of a single rich block's live state.
///
/// Built from `rich.update` SSE patches (or from a one-shot GET re-sync).
/// Generic — serves image blocks today, and question/CC blocks in the future.
class RichBlockState {
  final RichBlockStatus status;
  final int progress; // 0–100 (meaningful when status == generating)
  final int? imageId;
  final String? error;

  const RichBlockState({
    required this.status,
    this.progress = 0,
    this.imageId,
    this.error,
  });

  /// Builds state from a `rich.update` patch (or a GET /images/{id} body).
  ///
  /// [patch] shape:
  ///   {"status":"generating","progress":50}
  ///   {"status":"done","image_id":21}
  ///   {"status":"failed","error":"…"}
  ///
  /// [existingImageId] is carried forward from a previous state (SSE patches
  /// don't always include `image_id`).
  factory RichBlockState.fromPatch(
    Map<String, dynamic> patch, {
    int? existingImageId,
  }) {
    final statusStr = patch['status'] as String?;
    final status = switch (statusStr) {
      'done' => RichBlockStatus.done,
      'failed' => RichBlockStatus.failed,
      _ => RichBlockStatus.generating,
    };
    return RichBlockState(
      status: status,
      progress: _parseInt(patch['progress'], 0),
      imageId: _parseInt(patch['image_id'], existingImageId ?? 0),
      error: patch['error'] as String?,
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
