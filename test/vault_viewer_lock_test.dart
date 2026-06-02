// Regression test: vault viewers must close when the vault locks.
//
// Verifies that when vaultSessionProvider becomes null (simulating a
// tab switch, explicit lock, or future inactivity timer), any open viewer
// dialog is immediately dismissed — disposing the decrypted bytes and
// revoking blob URLs.
//
// Run:
//   flutter test --platform=chrome test/vault_viewer_lock_test.dart

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:bmo_app/features/vault/data/vault_client.dart';
import 'package:bmo_app/features/vault/data/vault_models.dart';
import 'package:bmo_app/features/vault/data/vault_repository.dart';
import 'package:bmo_app/features/vault/crypto/vault_kdf.dart';
import 'package:bmo_app/features/vault/presentation/viewers/vault_viewer_image.dart';
import 'package:bmo_app/features/vault/providers/vault_providers.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// A fake KDF that returns 32 zero bytes — avoids the argon2 WASM
/// dependency in test (viewers never call password operations).
class _FakeKdf implements VaultKdf {
  @override
  Future<Uint8List> derive({
    required Uint8List password,
    required Uint8List salt,
  }) async =>
      Uint8List(32);
}

VaultSession _testSession() => VaultSession(
      vaultId: 'test-vault-id',
      dek: Uint8List.fromList(List.generate(32, (i) => i)),
      kek: Uint8List.fromList(List.generate(32, (i) => i)),
      decryptedName: 'test-vault',
    );

VaultItemDecrypted _testItem() => VaultItemDecrypted(
      id: 'test-item-id',
      vaultId: 'test-vault-id',
      fileName: 'test-file.png',
      mimeType: 'image/png',
      originalSize: 1024,
      encryptionScheme: 'gcm_chunked',
      chunkSize: 1048576,
      sizeBytes: 1100,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

/// Creates a [VaultRepository] backed by a mock HTTP client that returns
/// 500 for all requests. The viewer shows an error state — but the lock
/// listener works independently of the download outcome.
VaultRepository _errorRepo() {
  final mockClient = MockClient((_) async => http.Response('{}', 500));
  final client = VaultClient(client: mockClient, baseUrl: 'http://127.0.0.1:1');
  return VaultRepository(client, kdf: _FakeKdf());
}

/// Pumps a [MaterialApp] with a button that opens [viewer] via [showDialog].
/// Injects a test session into [vaultSessionProvider] so the viewers can
/// observe it. Returns the [ProviderContainer] for triggering lock.
Future<ProviderContainer> _pumpWithViewer(
  WidgetTester tester,
  Widget viewer,
  VaultSession session,
) async {
  late final ProviderContainer container;

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Builder(
          builder: (context) {
            container = ProviderScope.containerOf(context);
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => viewer,
                  ),
                  child: const Text('OPEN_VIEWER'),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );

  // Inject the test session now that the tree is built. The viewers'
  // ref.listen will see the initial non-null session and then fire
  // when it transitions to null later in the test.
  container
      .read(vaultSessionProvider.notifier)
      .setTestSession(session);
  await tester.pump();

  // Open the viewer
  await tester.tap(find.text('OPEN_VIEWER'));
  await tester.pumpAndSettle();

  return container;
}

// ============================================================
// Tests
// ============================================================

void main() {
  group('Viewer closes on vault lock', () {
    testWidgets('Image viewer closes when session becomes null',
        (tester) async {
      final session = _testSession();
      final container = await _pumpWithViewer(
        tester,
        VaultImageViewer(
          item: _testItem(),
          session: session,
          repo: _errorRepo(),
          isMobile: false,
        ),
        session,
      );

      // Dialog is open
      expect(find.byType(VaultImageViewer), findsOneWidget);

      // Lock the vault → session → null
      container
          .read(vaultSessionProvider.notifier)
          .setTestSession(null);
      await tester.pumpAndSettle();

      // Dialog must be gone
      expect(find.byType(VaultImageViewer), findsNothing);
    });

    testWidgets('Dialog stays open if session remains valid',
        (tester) async {
      final session = _testSession();
      await _pumpWithViewer(
        tester,
        VaultImageViewer(
          item: _testItem(),
          session: session,
          repo: _errorRepo(),
          isMobile: false,
        ),
        session,
      );

      expect(find.byType(VaultImageViewer), findsOneWidget);

      // Do NOT lock — just pump again to verify no spontaneous close
      await tester.pumpAndSettle();
      expect(find.byType(VaultImageViewer), findsOneWidget);
    });
  });
}
