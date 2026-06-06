// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

/// Client-side thumbnail generation for vault item uploads.
///
/// Generates JPEG thumbnails from image and video files using browser APIs
/// (ImageElement, CanvasElement, VideoElement). Thumbnails are capped at
/// [kThumbnailMaxDimension] pixels on the longest side and exported as JPEG
/// at quality [kThumbnailJpegQuality].
///
/// ## Supported MIME types
/// - `image/*` — decoded and drawn on canvas, exported as JPEG.
/// - `video/*` — first frame (~1s seek) captured on canvas. Skipped if the
///   file exceeds [kVideoThumbnailMaxBytes] (200 MiB).
/// - Everything else (PDF, text, audio, etc.) — returns `null`.
///
/// ## Robustness
/// Every operation is wrapped in try/catch. Any failure returns `null` —
/// thumbnail is an enhancement; the content upload must always succeed.
///
/// ## Security
/// - NEVER log thumbnail bytes, file bytes, file names, or keys.
/// - Blob URLs are revoked immediately after use.
/// - Video elements receive full teardown: pause, clear src, remove.
/// - Thumbnail bytes live only in memory during the upload and are never
///   persisted.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

/// Maximum video file size for which a thumbnail is attempted (200 MiB).
const int kVideoThumbnailMaxBytes = 200 * 1024 * 1024;

/// Maximum width or height of the generated thumbnail in pixels.
const int kThumbnailMaxDimension = 256;

/// JPEG quality for canvas export (0.0 = worst, 1.0 = best).
const double kThumbnailJpegQuality = 0.7;

/// Timeout for loading an image (if the load hangs, abort).
const Duration kImageLoadTimeout = Duration(seconds: 10);

/// Timeout for seeking a video frame (if the seek hangs, abort).
const Duration kVideoSeekTimeout = Duration(seconds: 5);

/// Maximum thumbnail size in bytes before we reject it as suspicious.
const int _kMaxThumbnailBytes = 100 * 1024; // 100 KiB

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Generates a JPEG thumbnail from [fileBytes] based on [mimeType].
///
/// Returns the JPEG bytes on success, or `null` if:
/// - The MIME type is not supported (PDF, text, audio, etc.).
/// - The file is too large (video over [kVideoThumbnailMaxBytes]).
/// - Any step in the generation pipeline fails (corrupted file, timeout,
///   format not decodable, etc.).
///
/// ## Security
/// - NEVER log the returned bytes, [fileBytes], [mimeType], or file names.
/// - Blob URLs are revoked immediately after use.
/// - Video elements are torn down fully.
Future<Uint8List?> generateThumbnail(
  Uint8List fileBytes,
  String mimeType,
) async {
  try {
    if (mimeType.startsWith('image/')) {
      return await _generateImageThumbnail(fileBytes);
    }
    if (mimeType.startsWith('video/')) {
      return await _generateVideoThumbnail(fileBytes);
    }
    return null; // Unsupported MIME type
  } catch (_) {
    return null;
  }
}

// ---------------------------------------------------------------------------
// Image thumbnail
// ---------------------------------------------------------------------------

Future<Uint8List?> _generateImageThumbnail(Uint8List fileBytes) async {
  final blob = html.Blob([fileBytes]);
  final blobUrl = html.Url.createObjectUrl(blob);
  try {
    final image = html.ImageElement();
    final completer = Completer<void>();

    final loadSub = image.onLoad.listen((_) {
      if (!completer.isCompleted) completer.complete();
    });
    final errorSub = image.onError.listen((_) {
      if (!completer.isCompleted) {
        completer.completeError(const FormatException('Image load failed'));
      }
    });

    image.src = blobUrl;

    try {
      await completer.future.timeout(kImageLoadTimeout);
    } on TimeoutException {
      return null;
    } on FormatException {
      return null;
    } finally {
      loadSub.cancel();
      errorSub.cancel();
    }

    final naturalW = image.naturalWidth;
    final naturalH = image.naturalHeight;
    if (naturalW <= 0 || naturalH <= 0) return null;

    final (canvasW, canvasH) =
        _scaleDimensions(naturalW, naturalH, kThumbnailMaxDimension);

    final canvas = html.CanvasElement()
      ..width = canvasW
      ..height = canvasH;
    final ctx = canvas.context2D;
    ctx.scale(canvasW / naturalW, canvasH / naturalH);
    ctx.drawImage(image, 0, 0);

    final dataUrl = canvas.toDataUrl('image/jpeg', kThumbnailJpegQuality);
    final jpegBytes = _dataUrlToBytes(dataUrl);
    if (jpegBytes == null) return null;

    // Sanity check: reject unreasonably large thumbnails.
    if (jpegBytes.length > _kMaxThumbnailBytes) return null;

    return jpegBytes;
  } catch (_) {
    return null;
  } finally {
    html.Url.revokeObjectUrl(blobUrl);
  }
}

// ---------------------------------------------------------------------------
// Video thumbnail
// ---------------------------------------------------------------------------

Future<Uint8List?> _generateVideoThumbnail(Uint8List fileBytes) async {
  if (fileBytes.length > kVideoThumbnailMaxBytes) return null;

  final blob = html.Blob([fileBytes]);
  final blobUrl = html.Url.createObjectUrl(blob);
  html.VideoElement? video;
  try {
    video = html.VideoElement()
      ..src = blobUrl
      ..preload = 'metadata'
      ..muted = true;

    // Wait for video metadata (dimensions) to be available.
    // Use a completer with timeout + error listener so invalid/corrupted
    // video bytes don't hang indefinitely.
    final metaCompleter = Completer<void>();
    final metaSub = video.onLoadedMetadata.listen((_) {
      if (!metaCompleter.isCompleted) metaCompleter.complete();
    });
    final errorSub = video.onError.listen((_) {
      if (!metaCompleter.isCompleted) {
        metaCompleter.completeError(const FormatException('Video load failed'));
      }
    });
    try {
      await metaCompleter.future.timeout(kVideoSeekTimeout);
    } on TimeoutException {
      return null;
    } on FormatException {
      return null;
    } finally {
      metaSub.cancel();
      errorSub.cancel();
    }

    final videoW = video.videoWidth;
    final videoH = video.videoHeight;
    if (videoW <= 0 || videoH <= 0) return null;

    // Seek to ~1 second for a representative frame.
    video.currentTime = 1.0;

    final completer = Completer<void>();
    final seekSub = video.onSeeked.listen((_) {
      if (!completer.isCompleted) completer.complete();
    });
    try {
      await completer.future.timeout(kVideoSeekTimeout);
    } on TimeoutException {
      return null;
    } finally {
      seekSub.cancel();
    }

    final (canvasW, canvasH) =
        _scaleDimensions(videoW, videoH, kThumbnailMaxDimension);

    final canvas = html.CanvasElement()
      ..width = canvasW
      ..height = canvasH;
    final ctx = canvas.context2D;
    ctx.scale(canvasW / videoW, canvasH / videoH);
    ctx.drawImage(video, 0, 0);

    final dataUrl = canvas.toDataUrl('image/jpeg', kThumbnailJpegQuality);
    final jpegBytes = _dataUrlToBytes(dataUrl);
    if (jpegBytes == null) return null;

    // Sanity check: reject unreasonably large thumbnails.
    if (jpegBytes.length > _kMaxThumbnailBytes) return null;

    return jpegBytes;
  } catch (_) {
    return null;
  } finally {
    // Full teardown — matching the care from the video_player lesson.
    try {
      video?.pause();
      video?.src = '';
      video?.remove();
    } catch (_) {
      // Teardown errors are harmless; blob URL revocation is critical.
    }
    html.Url.revokeObjectUrl(blobUrl);
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Scales [width] × [height] to fit within [maxDim] while preserving aspect
/// ratio. Returns the original dimensions if already within bounds. Clamps
/// degenerate (≤0) inputs to 1×1.
(int, int) _scaleDimensions(int width, int height, int maxDim) {
  if (width <= 0 || height <= 0) return (1, 1);
  if (width <= maxDim && height <= maxDim) return (width, height);

  final scale = width > height ? maxDim / width : maxDim / height;
  return (
    (width * scale).round().clamp(1, maxDim),
    (height * scale).round().clamp(1, maxDim),
  );
}

/// Decodes a `data:image/jpeg;base64,...` (or `data:image/webp;base64,...`)
/// URL into raw bytes. Returns `null` if the URL format is unrecognizable.
Uint8List? _dataUrlToBytes(String dataUrl) {
  final comma = dataUrl.indexOf(',');
  if (comma < 0) return null;
  final base64Str = dataUrl.substring(comma + 1);
  try {
    return base64Decode(base64Str);
  } catch (_) {
    return null;
  }
}
