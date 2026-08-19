// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

import 'pdf_preview.dart';

/// Contadores de create/dispose — testes de vazamento de blob URL.
int pdfPreviewCreatedCount = 0;
int pdfPreviewDisposedCount = 0;

/// Preview web: blob URL + iframe com o visualizador de PDF do browser.
///
/// [dispose] revoga o blob URL — esquecer aqui é vazamento silencioso de
/// memória do navegador (os bytes decifrados ficam vivos enquanto o blob
/// existir).
class WebPdfPreview implements PdfPreview {
  WebPdfPreview(Uint8List bytes)
      : _blobUrl = html.Url.createObjectUrl(
          html.Blob([bytes], 'application/pdf'),
        );

  final String _blobUrl;
  bool _disposed = false;

  @override
  bool get isSystemPresented => false;

  @override
  Future<bool> present() async => true;

  @override
  Widget buildContent() => _PdfIframe(
        key: ValueKey(_blobUrl),
        blobUrl: _blobUrl,
      );

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    pdfPreviewDisposedCount++;
    html.Url.revokeObjectUrl(_blobUrl);
  }
}

/// Cria a fonte de preview desta plataforma.
///
/// `async` converte erros de criação do blob (ex.: falta de memória) em
/// erro do Future, capturável pelo call site com `await`.
Future<PdfPreview> createPdfPreview(Uint8List bytes) async {
  final preview = WebPdfPreview(bytes);
  pdfPreviewCreatedCount++;
  return preview;
}

// ---------------------------------------------------------------------------
// Global iframe element registry
// ---------------------------------------------------------------------------

/// Maps viewType → live `<iframe>` element so the platform view factory
/// can look up the element without capturing it in a closure.
final _iframeElements = <String, html.IFrameElement>{};

int _nextPdfViewId = 0;

/// Creates a unique viewType for a single viewer instance.
String _nextPdfViewType() => 'vault-pdf-${_nextPdfViewId++}';

/// Platform view factory.  Captures only [viewType] (a short string), NOT
/// the iframe element.
html.IFrameElement _pdfPlatformFactory(int viewId, String viewType) {
  return _iframeElements[viewType]!;
}

// ============================================================
// PDF iframe (browser's native PDF viewer)
// ============================================================

/// In-app PDF viewer content for the web: an iframe hosting the browser's
/// native PDF viewer.
///
/// ## Memory / platform view lifecycle
/// Same strategy as the video viewer: the platform view factory closes over
/// only a string key (viewType), looking up the actual iframe element from a
/// global map.  On dispose the entry is removed → the factory (stuck in the
/// registry forever) no longer reaches the element → GC collects the buffer.
class _PdfIframe extends StatefulWidget {
  final String blobUrl;

  const _PdfIframe({super.key, required this.blobUrl});

  @override
  State<_PdfIframe> createState() => _PdfIframeState();
}

class _PdfIframeState extends State<_PdfIframe> {
  late final html.IFrameElement _iframe;
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = _nextPdfViewType();
    _iframe = html.IFrameElement()
      ..src = widget.blobUrl
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.border = 'none';

    // Store in global registry so the factory can look it up without
    // capturing the element directly.
    _iframeElements[_viewType] = _iframe;

    // Register factory.  The closure captures only [_viewType], NOT
    // [_iframe] — see _pdfPlatformFactory.
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => _pdfPlatformFactory(viewId, _viewType),
    );
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }

  @override
  void dispose() {
    // Release the iframe's reference to the blob (so Chrome frees the
    // decoded PDF buffer) and remove from the global registry so the
    // factory (still held by platformViewRegistry) can no longer reach
    // this element → GC collects it.
    try {
      _iframe.src = '';
      if (_iframe.parentNode != null) {
        _iframe.remove();
      }
    } catch (_) {
      // Best-effort cleanup.
    }
    _iframeElements.remove(_viewType);
    super.dispose();
  }
}
