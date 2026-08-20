// Test-only seam: `flutter test --platform=chrome` does not run the web
// plugin registrant, so DArgon2Platform keeps EmptyDArgon2Flutter and every
// derive() throws UnimplementedError, even on chrome. The web implementation
// registers the platform by hand; on the VM it reports unavailable.
// Mesmo padrão de video_thumbnail_register.dart.
export 'argon2_register_stub.dart'
    if (dart.library.js_interop) 'argon2_register_web.dart';
