import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:get_thumbnail_video/video_thumbnail_web.dart';

/// flutter test does not run the generated web plugin registrant — without
/// this, VideoThumbnailPlatform keeps the MethodChannel default and every
/// call hangs.
void registerVideoThumbnailForTest() {
  VideoThumbnailWeb.registerWith(webPluginRegistrar);
}
