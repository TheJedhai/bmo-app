// Widget tests do modo de seleção múltipla do cofre.
//
// HTTP mockado com http/testing (MockClient) — VaultClient e
// VaultRepository reais por cima. O Argon2 real é trocado por um KDF fake
// determinístico: o material do cofre é gerado com o próprio
// crypto.createVault usando esse KDF, então o unlock pela UI valida o
// canary e decifra o DEK de verdade — só a derivação é falsa.
//
// Run: flutter test test/vault_screen_selection_test.dart

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:bmo_app/features/vault/crypto/vault_cipher.dart';
import 'package:bmo_app/features/vault/crypto/vault_crypto.dart' as crypto;
import 'package:bmo_app/features/vault/crypto/vault_envelope.dart';
import 'package:bmo_app/features/vault/crypto/vault_kdf.dart';
import 'package:bmo_app/features/vault/data/vault_client.dart';
import 'package:bmo_app/features/vault/data/vault_repository.dart';
import 'package:bmo_app/features/vault/presentation/vault_screen.dart';
import 'package:bmo_app/features/vault/providers/vault_providers.dart';

const _password = 'teste123';

/// KDF determinístico e instantâneo — o mesmo usado para gerar o material
/// (createVault) e desbloquear (testCanary/unwrapDek), então o canary
/// valida de verdade.
class _FakeKdf implements VaultKdf {
  @override
  Future<Uint8List> derive({
    required Uint8List password,
    required Uint8List salt,
  }) async {
    final key = Uint8List(32);
    for (var i = 0; i < key.length; i++) {
      key[i] = (salt[i % salt.length] ^ password[i % password.length]) & 0xff;
    }
    return key;
  }
}

Future<Map<String, dynamic>> _itemJson(
  Uint8List dek,
  String id,
  String fileName,
  String mimeType,
) async {
  final meta = utf8.encode(jsonEncode({
    'fileName': fileName,
    'mimeType': mimeType,
    'originalSize': 1024,
  }));
  final (iv, blob) =
      await const VaultCipher().encrypt(dek, Uint8List.fromList(meta));
  return {
    'id': id,
    'vault_id': 'v1',
    'metadata_blob': base64Encode(blob),
    'metadata_iv': base64Encode(iv),
    'encryption_scheme': 'gcm_chunked',
    'chunk_size': 65536,
    'size_bytes': 1024,
    'created_at': '2026-01-01T00:00:00Z',
    'updated_at': '2026-01-01T00:00:00Z',
  };
}

Future<void> _pumpUnlockedVault(
  WidgetTester tester,
  List<({String id, String fileName, String mimeType})> itemSpecs,
  List<String> deletedIds,
) async {
  // Material do cofre gerado pelo próprio código de produção — só o KDF
  // é fake (Argon2 real demoraria ~1s por derivação no teste). O DEK real
  // vem do desembrulho com o KEK fake: os metadados dos itens precisam
  // ser cifrados com ELE para a lista decifrar.
  final material = await crypto.createVault(
    _password,
    'Cofre',
    kdf: _FakeKdf(),
  );
  final kek = await _FakeKdf().derive(
    password: Uint8List.fromList(_password.codeUnits),
    salt: material.salt,
  );
  final dek = await unwrapDek(kek, material.dekIv, material.wrappedDek);
  final unlockJson = {'id': 'v1', ...material.toJson()};

  final items = [
    for (final s in itemSpecs)
      await _itemJson(dek, s.id, s.fileName, s.mimeType),
  ];

  final handler = (http.Request request) async {
    if (request.method == 'GET' &&
        request.url.path == '/api/v1/vaults/unlock-material') {
      return http.Response(jsonEncode([unlockJson]), 200);
    }
    if (request.method == 'GET' &&
        request.url.path == '/api/v1/vaults/v1/keys') {
      return http.Response(jsonEncode(unlockJson), 200);
    }
    if (request.method == 'GET' &&
        request.url.path == '/api/v1/vaults/v1/items') {
      return http.Response(jsonEncode(items), 200);
    }
    if (request.method == 'DELETE' &&
        request.url.path.startsWith('/api/v1/vaults/v1/items/')) {
      deletedIds.add(request.url.pathSegments.last);
      return http.Response('{}', 200);
    }
    return http.Response('not found', 404);
  };

  final repo = VaultRepository(
    VaultClient(client: MockClient(handler), baseUrl: 'http://test'),
    kdf: _FakeKdf(),
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [vaultRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: VaultScreen()),
    ),
  );
  await tester.pumpAndSettle();

  // Destrava pela UI de verdade.
  await tester.enterText(find.byType(TextField), _password);
  await tester.tap(find.text('Destravar'));
  await tester.pumpAndSettle();
  expect(find.text('foto1.jpg'), findsOneWidget, reason: 'cofre destravado');
}

void main() {
  testWidgets('selecionar, marcar 2 e cancelar limpa a seleção', (tester) async {
    final deleted = <String>[];

    await _pumpUnlockedVault(
      tester,
      [
        (id: 'a', fileName: 'foto1.jpg', mimeType: 'image/jpeg'),
        (id: 'b', fileName: 'nota.txt', mimeType: 'text/plain'),
      ],
      deleted,
    );

    // Entra no modo seleção pelo botão descobrível.
    await tester.tap(find.text('Selecionar'));
    await tester.pump();
    expect(find.text('0 selecionados'), findsOneWidget);

    // Zero selecionados desabilita as ações.
    IconButton downloadBtn() => tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.download_outlined));
    IconButton deleteBtn() => tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.delete_outline));
    expect(downloadBtn().onPressed, isNull);
    expect(deleteBtn().onPressed, isNull);

    // Marca dois itens.
    await tester.tap(find.text('foto1.jpg'));
    await tester.pump();
    expect(find.text('1 selecionado'), findsOneWidget);
    await tester.tap(find.text('nota.txt'));
    await tester.pump();
    expect(find.text('2 selecionados'), findsOneWidget);
    expect(downloadBtn().onPressed, isNotNull);
    expect(deleteBtn().onPressed, isNotNull);

    // Cancelar sai do modo e limpa a seleção.
    await tester.tap(find.text('Cancelar'));
    await tester.pump();
    expect(find.text('Selecionar'), findsOneWidget);
    expect(deleted, isEmpty, reason: 'cancelar não faz nada');

    await tester.tap(find.text('Selecionar'));
    await tester.pump();
    expect(find.text('0 selecionados'), findsOneWidget,
        reason: 'sair limpa a seleção');
  });

  testWidgets('apagar 2 mostra confirmação com contagem e chama a API',
      (tester) async {
    final deleted = <String>[];

    await _pumpUnlockedVault(
      tester,
      [
        (id: 'a', fileName: 'foto1.jpg', mimeType: 'image/jpeg'),
        (id: 'b', fileName: 'nota.txt', mimeType: 'text/plain'),
      ],
      deleted,
    );

    await tester.tap(find.text('Selecionar'));
    await tester.pump();
    await tester.tap(find.text('foto1.jpg'));
    await tester.tap(find.text('nota.txt'));
    await tester.pump();

    // Confirmação destrutiva com contagem.
    await tester.tap(find.widgetWithIcon(IconButton, Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('Apagar 2 itens?'), findsOneWidget);
    expect(find.textContaining('irreversível'), findsOneWidget);

    // Confirmar dispara um DELETE por item.
    await tester.tap(find.widgetWithText(FilledButton, 'Apagar 2 itens'));
    await tester.pumpAndSettle();
    expect(deleted.toSet(), {'a', 'b'});

    // Sai do modo seleção.
    expect(find.text('Selecionar'), findsOneWidget);
  });
}
