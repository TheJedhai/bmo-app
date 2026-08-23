import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Canal registrado no AppDelegate (Runner). `reloadTimelines` chama
/// `WidgetCenter.shared.reloadAllTimelines()`.
const MethodChannel _widgetReloadChannel = MethodChannel('bmo/widget_reload');

/// Janela de coalescência. Estado de luz mudando em rajada (WebSocket: vários
/// toggles em sequência, ou um device oscilando) não deve disparar uma
/// recarga por evento — aqui vira UMA recarga após o silêncio. Longa o
/// bastante pra agregar rajada, curta o bastante pra uma mudança real
/// aparecer em ~2s.
const Duration _debounceWindow = Duration(milliseconds: 2000);

Timer? _pendingReload;

/// Recarrega as timelines do WidgetKit sob demanda.
///
/// [debounced] = true coalesce chamadas próximas (estado mudando em sequência
/// vindo do WebSocket). O caso background é o não-debounced: no momento de
/// suspender queremos o estado MAIS RECENTE na tela, e um timer de 2s poderia
/// ser cortado pela suspensão do app.
void requestWidgetReload({bool debounced = false}) {
  _pendingReload?.cancel();
  if (debounced) {
    _pendingReload = Timer(_debounceWindow, _reload);
  } else {
    _reload();
  }
}

Future<void> _reload() async {
  _pendingReload = null;
  try {
    await _widgetReloadChannel.invokeMethod('reloadTimelines');
  } on MissingPluginException {
    // Sem a camada nativa (Android, desktop, flutter_tester): nada a recarregar.
  } catch (e) {
    debugPrint('Widget reload failed: $e');
  }
}
