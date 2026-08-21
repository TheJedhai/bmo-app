// Test-only seam: no chrome, AesGcm.with256bits() dispacha para
// BrowserAesGcm (crypto.subtle) — async REAL do navegador. Dentro de
// testWidgets (zona FakeAsync) a continuação do await só libera com pump,
// e o crypto do setup roda ANTES do primeiro pump: o teste pendura para
// sempre ("did not complete"). A variante web da seam troca
// Cryptography.instance para DartAesGcm puro (o mesmo do VM); todo o
// resto é no-op. Produção não muda — o dispatch é só nesta instância de
// teste. Mesmo padrão de video_thumbnail_register.dart.
//
// ATENÇÃO: não remova o import da seam de vault_screen_selection_test
// achando que ela só evita o hang do testWidgets. O bundle ANTIGO desse
// teste (sem a seam) também travava o runner web em runs longas: o
// pipeline serial congela no meio de outro suíte (vault_item_repository),
// silencioso, sem timeout (o watchdog de 3 s do flutter_web_platform
// marca "debugging" e suspende timeouts), reproduzível byte a byte.
// Medido: com a seam revertida, o stall volta; com a seam, some.
export 'vault_cipher_register_stub.dart'
    if (dart.library.js_interop) 'vault_cipher_register_web.dart';
