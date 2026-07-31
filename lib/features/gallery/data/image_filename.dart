import 'image_model.dart';

/// Builds a download filename for a [GalleryImage].
///
/// Without a prompt: `bmo-image-{id}.{ext}`.
/// With a prompt:    `bmo-image-{id}-{slug}.{ext}` (slug truncated at ~40 chars).
///
/// The [mimeType] (as reported by the server, e.g. `image/png`) determines the
/// file extension. Falls back to `png` for unknown types.
String galleryImageFileName(GalleryImage image, String mimeType) {
  final ext = _extFromMime(mimeType);
  final prompt = image.prompt;
  if (prompt == null || prompt.trim().isEmpty) {
    return 'bmo-image-${image.id}.$ext';
  }
  return 'bmo-image-${image.id}-${_toSlug(prompt)}.$ext';
}

String _extFromMime(String mimeType) {
  switch (mimeType) {
    case 'image/jpeg':
      return 'jpg';
    case 'image/png':
      return 'png';
    case 'image/webp':
      return 'webp';
    case 'image/gif':
      return 'gif';
    case 'image/svg+xml':
      return 'svg';
    default:
      return 'png';
  }
}

String _toSlug(String text) {
  // Lowercase, remove accents, non-alphanumeric → hyphen.
  final noAccents = _removeAccents(text.toLowerCase());
  final slug = noAccents
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
  if (slug.length <= 40) return slug;
  // Truncate without trailing hyphen.
  final truncated = slug.substring(0, 40);
  return truncated.replaceAll(RegExp(r'-$'), '');
}

String _removeAccents(String s) {
  const accents = {
    'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
    'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
    'ç': 'c', 'ñ': 'n',
  };
  return s.split('').map((c) => accents[c] ?? c).join();
}
