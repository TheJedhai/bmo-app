// Test-only seam: no chrome, AesGcm.with256bits() dispacha para
// BrowserAesGcm (crypto.subtle) — async REAL do navegador. Dentro de
// testWidgets (zona FakeAsync) a continuação do await só libera com pump,
// e o crypto do setup roda ANTES do primeiro pump: o teste pendura para
// sempre ("did not complete"). A variante web da seam troca
// Cryptography.instance para DartAesGcm puro (o mesmo do VM); todo o
// resto é no-op. Produção não muda — o dispatch é só nesta instância de
// teste. Mesmo padrão de video_thumbnail_register.dart.
export 'vault_cipher_register_stub.dart'
    if (dart.library.js_interop) 'vault_cipher_register_web.dart';
