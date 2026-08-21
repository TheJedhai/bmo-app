// Reconexão no resume (iOS): quando o app volta do background, SSE de
// negócio e WebSocket de devices devem reconectar — sem duplicar conexão,
// sem acumular listeners, sem resetar estado de UI, e com identidade
// re-resolvida no connect (nunca valor capturado).
//
// O reconnect é desligado na web por design (gate kIsWeb em
// AppLifecycleReconnect), então este arquivo só roda na VM. A anotação
// precisa ficar no nível da library — em cima de `void main()` o
// analyzer marca invalid_annotation_target e o runner ignora.
//
// Run:
//   flutter test test/app_lifecycle_reconnect_test.dart
@TestOn('vm')
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:bmo_app/core/events/events_provider.dart';
import 'package:bmo_app/core/http/bmo_http_client.dart';
import 'package:bmo_app/core/http/client_factory.dart';
import 'package:bmo_app/core/identity/identity_state.dart';
import 'package:bmo_app/core/widgets/app_lifecycle_reconnect.dart';
import 'package:bmo_app/features/home_devices/data/device.dart';
import 'package:bmo_app/features/home_devices/data/devices_ws_client.dart';
import 'package:bmo_app/features/home_devices/providers/devices_providers.dart';

// ---------------------------------------------------------------------------
// Spies
// ---------------------------------------------------------------------------

class _Spy {
  int connects = 0;
  int active = 0;
  int maxActive = 0;

  void onConnect() {
    connects++;
    active++;
    if (active > maxActive) maxActive = active;
  }

  void onCancel() => active--;
}

/// Gerador espião: conta conexões e fica pendurado até ser cancelado —
/// simula uma conexão viva que nunca termina por conta própria.
///
/// O decremento de ativos fica no `ref.onDispose` (e não no `finally` do
/// gerador): roda síncrono no invalidate, ANTES do rebuild — é a asserção
/// de "fecha antes de abrir" no nível do provider.
Stream<Map<String, dynamic>> _spySse(Ref ref, _Spy spy) async* {
  spy.onConnect();
  ref.onDispose(spy.onCancel);
  await Completer<Never>().future;
}

Stream<DeviceWsMessage> _spyWs(Ref ref, _Spy spy) async* {
  spy.onConnect();
  ref.onDispose(spy.onCancel);
  await Completer<Never>().future;
}

void _backgroundThenResume(WidgetTester tester) {
  // Ciclo real do iOS a partir de resumed (estado inicial do binding):
  // ida: inactive → hidden → paused (onPause); volta: hidden → inactive →
  // resumed (onResume). AppLifecycleListener tem assert de transição em
  // debug — sequências diferentes estouram.
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
}

Future<void> _pumpUntil(
    ProviderContainer container, bool Function() done) async {
  for (var i = 0; i < 50 && !done(); i++) {
    await container.pump();
  }
}

/// Pumpa alguns turns extras para a conexão corrente ficar 100% conectada
/// (subscription http atribuída) antes de trocar de identidade/invalidar.
Future<void> _settlePumps(ProviderContainer container) async {
  for (var i = 0; i < 5; i++) {
    await container.pump();
  }
}

// ---------------------------------------------------------------------------
// Lifecycle widget
// ---------------------------------------------------------------------------

void main() {
  testWidgets(
      'resumed após background reconecta SSE e WS, sem duplicar nem acumular',
      (tester) async {
    final sse = _Spy();
    final ws = _Spy();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        eventsStreamProvider.overrideWith((ref) => _spySse(ref, sse)),
        devicesWsStreamProvider.overrideWith((ref) => _spyWs(ref, ws)),
      ],
      child: const AppLifecycleReconnect(child: SizedBox()),
    ));

    final container = ProviderScope.containerOf(
        tester.element(find.byType(AppLifecycleReconnect)));
    final subscriptions = [
      container.listen(eventsStreamProvider, (_, _) {}),
      container.listen(devicesWsStreamProvider, (_, _) {}),
    ];
    // tester.pump, não container.pump: dentro do FakeAsync do testWidgets o
    // vsync do container (fim de frame) só dispara com pump de frame —
    // container.pump() esperaria o vsync que nunca vem.
    await tester.pump();
    expect(sse.connects, 1);
    expect(ws.connects, 1);

    _backgroundThenResume(tester);
    await tester.pump();
    expect(sse.connects, 2);
    expect(ws.connects, 2);
    expect(sse.maxActive, 1);
    expect(ws.maxActive, 1);
    expect(sse.active, 1);
    expect(ws.active, 1);

    // Segundo ciclo (resume trivial, ex. centro de notificações):
    // reconecta de novo, mas sem acumular nada além.
    _backgroundThenResume(tester);
    await tester.pump();
    expect(sse.connects, 3);
    expect(ws.connects, 3);
    expect(sse.maxActive, 1);
    expect(ws.maxActive, 1);

    for (final sub in subscriptions) {
      sub.close();
    }
    await tester.pump();
  });

  testWidgets('resume sem pause prévio (cold start) não reconecta',
      (tester) async {
    final sse = _Spy();
    final ws = _Spy();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        eventsStreamProvider.overrideWith((ref) => _spySse(ref, sse)),
        devicesWsStreamProvider.overrideWith((ref) => _spyWs(ref, ws)),
      ],
      child: const AppLifecycleReconnect(child: SizedBox()),
    ));

    final container = ProviderScope.containerOf(
        tester.element(find.byType(AppLifecycleReconnect)));
    final subscriptions = [
      container.listen(eventsStreamProvider, (_, _) {}),
      container.listen(devicesWsStreamProvider, (_, _) {}),
    ];
    await tester.pump();
    expect(sse.connects, 1);

    // iOS dispara inactive → resumed no launch. Sem pause anterior,
    // não há motivo para derrubar a conexão recém-aberta.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    // Vários pumps, não um: um invalidate só vira reconexão observável
    // depois de alguns frames. Com um pump único a asserção passaria mesmo
    // se o guard `_backgrounded` sumisse — não distinguiria "não
    // reconectou" de "ainda não reconectou".
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
    expect(sse.connects, 1);
    expect(ws.connects, 1);

    for (final sub in subscriptions) {
      sub.close();
    }
    await tester.pump();
  });

  // -------------------------------------------------------------------------
  // SSE: identidade re-resolvida na reconexão, fecha antes de abrir
  // -------------------------------------------------------------------------

  test('SSE reconecta com X-User-Id fresco, nunca duplicando conexão',
      () async {
    final captured = <String?>[];
    final events = <String>[];
    var opens = 0;
    var inFlight = 0;

    final container = ProviderContainer(overrides: [
      // Sobrescrever httpClientProvider (e não eventsClientProvider) para
      // exercitar o caminho real de injeção: BmoHttpClient.send lê o getter
      // a cada request.
      httpClientProvider.overrideWith(
        (ref) => BmoHttpClient(
          MockClient.streaming((request, _) async {
            captured.add(request.headers['X-User-Id']);
            events.add('open${++opens}');
            inFlight++;
            final controller = StreamController<List<int>>(
              onCancel: () {
                events.add('cancel$opens');
                inFlight--;
              },
            );
            return http.StreamedResponse(controller.stream, 200,
                headers: {'content-type': 'text/event-stream'});
          }),
          () => ref.read(currentUserIdProvider)?.toString() ?? '',
        ),
      ),
    ]);
    addTearDown(container.dispose);

    // eventsListenerProvider é quem invalida o stream na troca de
    // identidade (mesma wiring da produção, via _AppShell).
    container.listen(eventsListenerProvider, (_, _) {});
    container.read(currentUserIdProvider.notifier).state = 1;
    await _pumpUntil(container, () => captured.length == 1);
    await _settlePumps(container);
    expect(captured, ['1']);

    // Troca de perfil: invalidate cancela a conexão antiga (síncrono) antes
    // de reconectar com a identidade nova.
    container.read(currentUserIdProvider.notifier).state = 2;
    await _pumpUntil(container, () => captured.length == 2);
    await _settlePumps(container);
    expect(captured, ['1', '2']);

    // Caminho do resume: idem — a identidade sai da resolução viva no
    // connect, não de valor capturado.
    container.invalidate(eventsStreamProvider);
    await _pumpUntil(container, () => captured.length == 3);
    expect(captured, ['1', '2', '2']);
    // Cancel síncrono: cada open é precedido pelo cancel da conexão
    // anterior — nunca duas abertas ao mesmo tempo.
    expect(events, ['open1', 'cancel1', 'open2', 'cancel2', 'open3']);
    expect(inFlight, 1);
  });

  // -------------------------------------------------------------------------
  // WebSocket de devices: restart sem duplicar, no-op sem listener
  // -------------------------------------------------------------------------

  test('WS de devices reinicia no invalidate sem duplicar conexão', () async {
    final client = _CountingWsClient();
    final container = ProviderContainer(overrides: [
      devicesWsClientProvider.overrideWithValue(client),
    ]);
    addTearDown(container.dispose);

    final sub = container.listen(devicesWsStreamProvider, (_, _) {});
    await _pumpUntil(container, () => client.connects == 1);
    expect(client.active, 1);

    container.invalidate(devicesWsStreamProvider);
    await _pumpUntil(container, () => client.connects == 2);
    expect(client.maxActive, 1);
    expect(client.active, 1);

    // Sem listener ativo, invalidate é no-op até o próximo listen.
    sub.close();
    container.invalidate(devicesWsStreamProvider);
    await container.pump();
    expect(client.connects, 2);
  });
}

class _CountingWsClient extends DevicesWsClient {
  int connects = 0;
  int active = 0;
  int maxActive = 0;

  _CountingWsClient() : super(baseUrl: 'wss://test.local');

  @override
  Stream<DeviceWsMessage> connect() {
    connects++;
    active++;
    if (active > maxActive) maxActive = active;
    late final StreamController<DeviceWsMessage> controller;
    controller = StreamController<DeviceWsMessage>(
      onCancel: () => active--,
    );
    return controller.stream;
  }
}
