import 'dart:io';
import 'dart:math';

import 'package:bmo_app/core/platform/temp_orphan_sweep.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('sweepOrphanTempFiles', () {
    test('apaga órfãos BMO e preserva outros arquivos do temp', () async {
      final Directory dir = Directory.systemTemp;
      final String tag =
          '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(1 << 32)}';

      final File bmoVideo = File('${dir.path}/bmo_video_$tag.mp4');
      final File bmoPdf = File('${dir.path}/bmo_pdf_$tag.pdf');
      final File bmoDownload = File('${dir.path}/bmo_download_$tag.bin');
      final File foreign = File('${dir.path}/not_bmo_$tag.txt');

      await bmoVideo.writeAsString('x');
      await bmoPdf.writeAsString('x');
      await bmoDownload.writeAsString('x');
      await foreign.writeAsString('x');

      try {
        await sweepOrphanTempFiles();

        expect(await bmoVideo.exists(), isFalse);
        expect(await bmoPdf.exists(), isFalse);
        expect(await bmoDownload.exists(), isFalse);
        // Fora dos prefixos: fica intacto.
        expect(await foreign.exists(), isTrue);
      } finally {
        for (final File f in [bmoVideo, bmoPdf, bmoDownload, foreign]) {
          if (await f.exists()) await f.delete();
        }
      }
    });
  });
}
