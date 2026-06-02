import '../../../core/config/env.dart';

/// Builds the bmo-server image-proxy URL for an external image.
///
/// Flutter web cannot load images from arbitrary origins due to CORS;
/// bmo-server exposes a proxy at GET /api/v1/image-proxy that fetches
/// the image server-side and serves it from our own domain.
///
/// When [externalUrl] is `null` or empty the caller should skip the proxy
/// entirely and show a placeholder — this function requires a non-empty URL.
String articleImageProxyUrl(String externalUrl) {
  return '${Env.bmoServerUrl}/api/v1/image-proxy'
      '?url=${Uri.encodeComponent(externalUrl)}';
}
