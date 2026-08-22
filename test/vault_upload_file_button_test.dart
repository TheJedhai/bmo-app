// Testes do botão "Arquivo" (file_picker) — cobrem as duas rotas de upload que
// `_pickAndUploadFiles` decide pelo DADO (`file.bytes != null`), sem checar a
// plataforma:
//
// - bytes == null (withData:false, nativo): o XFile do PlatformFile aponta para
//   a cópia em cache do arquivo em disco -> rota STREAMADA. Provamos aqui o
//   registro que essa rota produz (originalFile set, bytes null, mime pela
//   cabeça) via buildPendingForUpload, num test() síncrono real — a leitura da
//   cabeça é I/O de arquivo, que o fake-async do WidgetTester não resolve.
//   O LIMITE de memória do corpo em voo (≤ chunkSize, não proporcional ao
//   arquivo) é provado à parte em vault_upload_memory_test.dart, que drive
//   repo.uploadItem(originalFile: XFile(path)) — o MESMO _uploadChunked que
//   esta rota alcança.
// - bytes != null (withData:true, web): sem original acessível -> rota
//   MEMÓRIA, um único POST a `/items`, nenhum chunk (testWidgets abaixo).
//
// O repo é o VaultRepository de produção (final, não-spiável); a rota memória
// é verificada pelos endpoints que o MockClient recebe.
//
// Run: flutter test test/vault_upload_file_button_test.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cross_file/cross_file.dart';

import 'package:bmo_app/features/vault/crypto/vault_chunked_cipher.dart';
import 'package:bmo_app/features/vault/crypto/vault_crypto.dart' as crypto;
import 'package:bmo_app/features/vault/crypto/vault_envelope.dart';
import 'package:bmo_app/features/vault/crypto/vault_kdf.dart';
import 'package:bmo_app/features/vault/data/vault_client.dart';
import 'package:bmo_app/features/vault/data/vault_repository.dart';
import 'package:bmo_app/features/vault/presentation/vault_screen.dart';
import 'package:bmo_app/features/vault/providers/vault_providers.dart';

import 'vault_cipher_register.dart';

const _password = 'teste123';

/// KDF determinístico e instantâneo — o mesmo para gerar o material e
/// desbloquear, então o canary valida de verdade (igual aos outros testes
/// de cofre).
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

/// Mock do file_picker: devolve sempre um único [PlatformFile] montado pelo
/// teste. Ignora `withData` (é o seam quem decide na plataforma real); aqui
/// configuramos `bytes`/`path` direto para simular cada lado.
class _MockPicker extends FilePicker {
  _MockPicker(this.file);
  final PlatformFile file;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    return FilePickerResult([file]);
  }
}

/// Servidor HTTP de teste: responde o fluxo de unlock/list do cofre E ambos
/// os contratos de upload — chunked (streaming) e POST único (memória) —,
/// gravando o que recebeu para o assertion decidir qual rota foi usada.
class _UploadServer {
  _UploadServer(this._unlockJson);
  final Map<String, dynamic> _unlockJson;

  final List<Uint8List> chunks = [];
  int putCalls = 0;
  int memUploads = 0;
  final _complete = Completer<void>();

  /// Completa quando o upload terminou (completeChunkedUpload).
  Future<void> get done => _complete.future;

  http.Client client() {
    return MockClient((request) async {
      final path = request.url.path;
      if (request.method == 'GET' &&
          path == '/api/v1/vaults/unlock-material') {
        return http.Response(jsonEncode([_unlockJson]), 200);
      }
      if (request.method == 'GET' && path == '/api/v1/vaults/v1/keys') {
        return http.Response(jsonEncode(_unlockJson), 200);
      }
      if (request.method == 'GET' && path == '/api/v1/vaults/v1/items') {
        return http.Response(jsonEncode([]), 200);
      }
      // Streaming (chunked).
      if (request.method == 'POST' &&
          path == '/api/v1/vaults/v1/items/uploads') {
        return http.Response(
          jsonEncode({'upload_id': 'u1', 'expected_size': 0}),
          201,
          headers: {'content-type': 'application/json'},
        );
      }
      final chunkMatch = RegExp(
        r'/api/v1/vaults/v1/items/uploads/u1/chunks/(\d+)$',
      ).firstMatch(path);
      if (request.method == 'PUT' && chunkMatch != null) {
        putCalls++;
        chunks.add(Uint8List.fromList(request.bodyBytes));
        return http.Response('', 204);
      }
      if (request.method == 'POST' &&
          path == '/api/v1/vaults/v1/items/uploads/u1/complete') {
        if (!_complete.isCompleted) _complete.complete();
        return _item();
      }
      // In-memory (blob único).
      if (request.method == 'POST' && path == '/api/v1/vaults/v1/items') {
        memUploads++;
        return _item();
      }
      return http.Response('not found', 404);
    });
  }

  http.Response _item() {
    return http.Response(
      jsonEncode({
        'id': '10',
        'vault_id': 'v1',
        'metadata_blob': base64Encode(Uint8List(16)),
        'metadata_iv': base64Encode(Uint8List(12)),
        'encryption_scheme': 'gcm_chunked',
        'chunk_size': VaultChunkedCipher.defaultChunkSize,
        'size_bytes': 0,
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-01T00:00:00Z',
      }),
      201,
      headers: {'content-type': 'application/json'},
    );
  }
}

/// Bytes pseudo-aleatórios que não casam com nenhum magic number conhecido
/// (JPEG `FF D8 FF`, PNG `89 50 4E 47`, PDF `25 50 44 46`, GIF `47 49 46`,
/// BMP `42 4D`...) — então [detectMimeType] cai na extensão `.bin` →
/// application/octet-stream (não-imagem, caminho ideal pro teste).
Uint8List _nonMagicBytes(int length) {
  final bytes = Uint8List(length);
  for (var i = 0; i < length; i++) {
    bytes[i] = (i * 31 + 7) & 0xff;
  }
  return bytes;
}

Future<File> _writeTempFile(int megaBytes) async {
  final file = File(
    '${Directory.systemTemp.path}/bmo_arquivo_${DateTime.now().microsecondsSinceEpoch}.bin',
  );
  final sink = file.openWrite();
  final block = _nonMagicBytes(1024 * 1024);
  for (var m = 0; m < megaBytes; m++) {
    sink.add(block);
  }
  await sink.close();
  return file;
}

/// Sobe o VaultScreen destravado (material real via crypto, só o KDF é fake),
/// sobre o [_UploadServer], e injeta o mock do picker.
Future<_UploadServer> _pumpUnlocked(
  WidgetTester tester,
  PlatformFile pickedFile,
) async {
  final material = await crypto.createVault(_password, 'Cofre', kdf: _FakeKdf());
  final kek = await _FakeKdf().derive(
    password: Uint8List.fromList(_password.codeUnits),
    salt: material.salt,
  );
  final _ = await unwrapDek(kek, material.dekIv, material.wrappedDek);
  final unlockJson = {'id': 'v1', ...material.toJson()};

  final server = _UploadServer(unlockJson);
  final repo = VaultRepository(
    VaultClient(client: server.client(), baseUrl: 'http://test'),
    kdf: _FakeKdf(),
  );
  FilePicker.platform = _MockPicker(pickedFile);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [vaultRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: VaultScreen()),
    ),
  );
  await tester.pumpAndSettle();

  await tester.enterText(find.byType(TextField), _password);
  await tester.tap(find.text('Destravar'));
  await tester.pumpAndSettle();
  expect(find.text('Selecionar'), findsOneWidget, reason: 'cofre destravado');
  return server;
}

/// Abre o menu "Adicionar ao cofre" e seleciona "Arquivo".
Future<void> _tapArquivo(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.add));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Arquivo'));
  await tester.pumpAndSettle();
}

void main() {
  registerVaultCipherForWebTests();

  test('Arquivo bytes null (withData false, nativo): buildPendingForUpload '
      'entrega originalFile set, bytes null e mime pela cabeça', () async {
    // Arquivo grande não-mídia, conteúdo sem magic number (vira octet-stream).
    final file = await _writeTempFile(2);
    addTearDown(() {
      try {
        file.deleteSync();
      } catch (_) {}
    });

    // Igual à rota nativa: o XFile do PlatformFile carrega o path em disco;
    // o nome original vem de fora (PlatformFile.name), não do path em cache.
    final item = await buildPendingForUpload(
      XFile(file.path),
      fileName: 'big.bin',
      maxBytes: 4096, // _kMimeSniffMaxBytes
    );

    expect(item, isNotNull);
    expect(item!.fileName, 'big.bin');
    expect(item.mimeType, 'application/octet-stream');
    // Rota STREAMADA: original presente (uploads por chunks), bytes não
    // materializados (exceto imagem, que aqui não é).
    expect(item.originalFile, isNotNull, reason: 'trocou bytes por streaming');
    expect(item.originalFile!.path, file.path);
    expect(item.bytes, isNull);
    expect(item.sourcePath, file.path);
  });

  testWidgets('Arquivo: bytes presentes (withData true, web) fica na rota '
      'memória — um POST, sem chunks', (tester) async {
    final bytes = _nonMagicBytes(64 * 1024);

    final server = await _pumpUnlocked(
      tester,
      PlatformFile(
        name: 'big.bin',
        path: '/nao-real/na-web-nao-tem-path', // bytes presentes, path não usado
        size: bytes.length,
        bytes: bytes,
      ),
    );

    await _tapArquivo(tester);
    await tester.pumpAndSettle();

    expect(server.memUploads, 1, reason: 'rota memória via POST único');
    expect(server.putCalls, 0, reason: 'sem streaming (sem original)');
    expect(server.chunks, isEmpty);
  });
}
