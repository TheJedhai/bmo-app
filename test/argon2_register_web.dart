import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:dargon2_flutter_platform_interface/dargon2_flutter_platform.dart';
import 'package:dargon2_flutter_web/src/argon2.dart';

/// flutter test does not run the generated web plugin registrant — without
/// this, DArgon2Platform keeps EmptyDArgon2Flutter and every derive() throws
/// UnimplementedError, even on chrome.
///
/// No harness do teste o web/index.html não carrega, então window.hashwasm
/// começa nulo e o dargon2 busca o módulo no CDN sob demanda na primeira
/// derive() (mesmo fluxo do happy path do vault_cdn_defense_test). Espera o
/// módulo aparecer antes de devolver true.
Future<bool> registerArgon2ForTest() async {
  DArgon2Platform.instance = DArgon2FlutterWeb();
  for (var i = 0; i < 100; i++) {
    if (globalContext['hashwasm'] != null) return true;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  return false;
}
