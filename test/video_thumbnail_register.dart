// Test-only seam: `flutter test --platform=chrome` does not run the web
// plugin registrant, so method channels on web tests hang. The web
// implementation of the seam registers the plugin by hand; everywhere else
// it's a no-op.
export 'video_thumbnail_register_stub.dart'
    if (dart.library.js_interop) 'video_thumbnail_register_web.dart';
