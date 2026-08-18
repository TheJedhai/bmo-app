// Camada 1 of the CDN-fallback defense (see lib/features/vault/crypto/).
//
// dargon2_flutter_web registers hash-wasm by checking `window.hashwasm`;
// when that global is null, it injects a dynamic `import()` from
// cdn.jsdelivr.net — unacceptable for a zero-knowledge vault.
//
// This guard lives in an external file (same CSP class as
// flutter_bootstrap.js), so it also holds when inline scripts are
// blocked:
//
// 1. Synchronously: if `window.hashwasm` is missing, install a throwing
//    stub before Flutter ever boots, so dargon2 never reaches the CDN.
// 2. On window load: if the self-hosted /hash-wasm/index.esm.js module
//    never overwrote the stub (marker `__bmoStub` still set), fail early
//    and visibly with a full-screen overlay — the vault must not
//    silently degrade.
(function () {
  'use strict';

  function throwingStub() {
    throw new Error(
      'hash-wasm WASM module not loaded. ' +
        'The self-hosted /hash-wasm/index.esm.js failed to initialize. ' +
        'The vault cannot derive keys.'
    );
  }

  if (!window.hashwasm) {
    // Camada 2 (inline stub in index.html) did not run — e.g. CSP blocked
    // inline scripts. Install the failsafe ourselves before Flutter boots.
    window.hashwasm = {
      __bmoStub: true,
      argon2i: throwingStub,
      argon2d: throwingStub,
      argon2id: throwingStub,
      argon2Verify: throwingStub,
    };
  }

  window.addEventListener('load', function () {
    if (!(window.hashwasm && window.hashwasm.__bmoStub === true)) {
      return; // real module loaded, vault operational
    }

    var overlay = document.createElement('div');
    overlay.textContent =
      'BMO: hash-wasm WASM module not loaded. ' +
      'The self-hosted /hash-wasm/index.esm.js failed to initialize. ' +
      'The vault cannot derive keys.';
    overlay.setAttribute(
      'style',
      'position:fixed;top:0;left:0;right:0;bottom:0;' +
        'background:#1E1F23;color:#B8E0C2;' +
        'display:flex;align-items:center;justify-content:center;' +
        'text-align:center;font-family:monospace;font-size:16px;' +
        'padding:32px;z-index:999999;'
    );
    document.body.appendChild(overlay);
  });
})();
