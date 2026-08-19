/// Client-side thumbnail generation for vault item uploads.
///
/// Generates JPEG thumbnails from image and video files. Thumbnails are
/// capped at [kThumbnailMaxDimension] pixels on the longest side and exported
/// as JPEG at quality [kThumbnailJpegQuality].
///
/// ## Supported MIME types
/// - `image/*` — decoded and resized with package:image, exported as JPEG.
/// - `video/*` — frame at ~1s captured via get_thumbnail_video. Skipped if
///   the file exceeds [kVideoThumbnailMaxBytes] (200 MiB).
/// - Everything else (PDF, text, audio, etc.) — returns `null`.
///
/// ## Robustness
/// Every operation is wrapped in try/catch. Any failure returns `null` —
/// thumbnail is an enhancement; the content upload must always succeed.
/// HEIC/AVIF/SVG return `null` (no decoder in package:image); a server-side
/// thumbnail is impossible by design — the vault is zero-knowledge, the
/// stored blob is opaque.
///
/// ## Security
/// - NEVER log thumbnail bytes, file bytes, file names, or keys.
/// - [VideoSource] instances are always disposed, even on failure — they
///   wrap decrypted bytes (blob URL on web, temp file on native).
/// - Thumbnail bytes live only in memory during the upload and are never
///   persisted.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:get_thumbnail_video/index.dart' show ImageFormat;
import 'package:get_thumbnail_video/video_thumbnail.dart';
import 'package:image/image.dart' as img;

import '../../../core/platform/video_source.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

/// Maximum video file size for which a thumbnail is attempted (200 MiB).
const int kVideoThumbnailMaxBytes = 200 * 1024 * 1024;

/// Maximum width or height of the generated thumbnail in pixels.
const int kThumbnailMaxDimension = 256;

/// JPEG quality for the generated thumbnail (0.0 = worst, 1.0 = best).
const double kThumbnailJpegQuality = 0.7;

/// Timeout for capturing a video frame (if the capture hangs, abort).
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
/// - [VideoSource] instances are disposed even on failure.
Future<Uint8List?> generateThumbnail(
  Uint8List fileBytes,
  String mimeType,
) async {
  try {
    if (mimeType.startsWith('image/')) {
      return _generateImageThumbnail(fileBytes);
    }
    if (mimeType.startsWith('video/')) {
      return await getThumbnailVideo(fileBytes, mimeType);
    }
    return null; // Unsupported MIME type
  } catch (_) {
    return null;
  }
}

// ---------------------------------------------------------------------------
// Image thumbnail
// ---------------------------------------------------------------------------

Uint8List? _generateImageThumbnail(Uint8List fileBytes) {
  // HEIC, AVIF and SVG have no decoder in package:image — decodeImage
  // returns null and so do we.
  final decoded = img.decodeImage(fileBytes);
  if (decoded == null) return null;

  final (targetW, targetH) = _scaleDimensions(
    decoded.width,
    decoded.height,
    kThumbnailMaxDimension,
  );
  final resized = img.copyResize(
    decoded,
    width: targetW,
    height: targetH,
    // average = area sampling; matches the browser's canvas downscale.
    // linear/cubic are point filters — visibly blocky on photos.
    interpolation: img.Interpolation.average,
  );
  final jpegBytes = img.encodeJpg(
    resized,
    quality: (kThumbnailJpegQuality * 100).round(),
  );

  // Sanity check: reject unreasonably large thumbnails.
  if (jpegBytes.length > _kMaxThumbnailBytes) return null;

  return jpegBytes;
}

// ---------------------------------------------------------------------------
// Video thumbnail
// ---------------------------------------------------------------------------

/// Generates a JPEG thumbnail of the frame at ~1s of [fileBytes].
///
/// The bytes go through a [VideoSource]: blob URL on web, temp file on
/// native — the seam resolves the platform. The source wraps decrypted
/// bytes, so it is disposed even on failure.
///
/// The frame is captured at original resolution and then goes through the
/// same image pipeline: the plugin's own maxWidth/maxHeight fit-box would
/// upscale videos smaller than [kThumbnailMaxDimension], which the old
/// pipeline never did.
///
/// Returns `null` if the file is too large, the frame capture fails or
/// times out, or the result exceeds [_kMaxThumbnailBytes].
Future<Uint8List?> getThumbnailVideo(
  Uint8List fileBytes,
  String mimeType,
) async {
  if (fileBytes.length > kVideoThumbnailMaxBytes) return null;

  final source = await createVideoSource(fileBytes, mimeType);
  try {
    final frameBytes = await VideoThumbnail.thumbnailData(
      video: source.uri.toString(),
      imageFormat: ImageFormat.JPEG,
      maxWidth: 0, // original resolution — resized by the image pipeline
      maxHeight: 0,
      timeMs: 1000, // ~1s for a representative frame
      quality: 90, // intermediate; final JPEG uses kThumbnailJpegQuality
    ).timeout(kVideoSeekTimeout);

    return _generateImageThumbnail(frameBytes);
  } catch (_) {
    return null;
  } finally {
    source.dispose();
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
