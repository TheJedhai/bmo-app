import 'package:mime/mime.dart';

/// Detector de mime por conteúdo (magic number), não por extensão.
///
/// Extensão não é confiável: é metadado editável. Caso real: um HEIC do
/// app Fotos renomeado para .jpg era gravado no cofre como image/jpeg,
/// quebrava thumbnail e visualizador — e o campo errado ficava salvo.
///
/// Usa o package:mime (MimeTypeResolver com os magic numbers default:
/// JPEG, PNG, GIF, WebP, TIFF, PDF, HEIC 'heic'/'heix', HEIF 'mif1',
/// MP4...) mais os formatos que ele não cobre: BMP, AVIF, MOV e marcas
/// HEIC/HEIF menos comuns. Para ISO-BMFF a distinção vem do brand em
/// 'ftyp' (offset 8), não do container.
final MimeTypeResolver _resolver = _buildResolver();

MimeTypeResolver _buildResolver() {
  final resolver = MimeTypeResolver();
  // 'BM' — Bitmap, sem header ISO.
  resolver.addMagicNumber([0x42, 0x4D], 'image/bmp');
  _addFtyp(resolver, 'avif', 'image/avif');
  _addFtyp(resolver, 'avis', 'image/avif');
  _addFtyp(resolver, 'qt  ', 'video/quicktime');
  _addFtyp(resolver, 'hevc', 'image/heic');
  _addFtyp(resolver, 'hevx', 'image/heic');
  _addFtyp(resolver, 'heim', 'image/heic');
  _addFtyp(resolver, 'heis', 'image/heic');
  _addFtyp(resolver, 'msf1', 'image/heif');
  return resolver;
}

/// Magic number ISO-BMFF: 4 bytes de tamanho do box (ignorados via mask) +
/// 'ftyp' + [brand] de 4 bytes.
void _addFtyp(MimeTypeResolver resolver, String brand, String mime) {
  resolver.addMagicNumber(
    [0, 0, 0, 0, 0x66, 0x74, 0x79, 0x70, ...brand.codeUnits],
    mime,
    mask: [0, 0, 0, 0, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF],
  );
}

/// Detecta o mime de [bytes] pelo conteúdo; se os bytes não identificarem
/// nada, cai na extensão de [fileName]; sem extensão conhecida,
/// application/octet-stream.
///
/// Ordem: bytes -> extensão -> application/octet-stream. Nunca o contrário.
/// Bytes vazios ou menores que o header não quebram: caem na extensão.
String detectMimeType({required List<int> bytes, required String fileName}) =>
    _resolver.lookup(fileName, headerBytes: bytes) ??
    'application/octet-stream';
