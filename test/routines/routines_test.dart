// Presença e sino de avisos (etapa 9): opções do diálogo, PUT com o estado
// escolhido e badge só das seguradas ainda não entregues.
//
// Run:
//   flutter test test/routines/routines_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:bmo_app/core/events/events_provider.dart';
import 'package:bmo_app/core/identity/identity_state.dart';
import 'package:bmo_app/core/theme/bmo_theme.dart';
import 'package:bmo_app/features/routines/data/routines_client.dart';
import 'package:bmo_app/features/routines/data/routines_repository.dart';
import 'package:bmo_app/features/routines/providers/routines_providers.dart';
import 'package:bmo_app/features/routines/widgets/notifications_bell.dart';
import 'package:bmo_app/features/routines/widgets/presence_button.dart';

class FakeRoutinesRepository extends RoutinesRepository {
  FakeRoutinesRepository()
    : super(RoutinesClient(client: http.Client(), baseUrl: 'http://fake'));

  Presence presence = const Presence(mode: PresenceMode.emCasa);
  PresenceMode? lastMode;
  DateTime? lastUntil;

  List<AppNotification> notifications = const [];

  @override
  Future<Presence> getPresence() async => presence;

  @override
  Future<Presence> setPresence(PresenceMode mode, {DateTime? until}) async {
    lastMode = mode;
    lastUntil = until;
    presence = Presence(mode: mode, until: until);
    return presence;
  }

  @override
  Future<List<AppNotification>> listNotifications({int limit = 50}) async =>
      notifications;
}

AppNotification _notification({
  int id = 1,
  String channel = 'celular',
  String? deliveredAt,
}) => AppNotification.fromJson({
  'id': id,
  'level': 'aviso',
  'title': 'título $id',
  'body': 'corpo $id',
  'source': 'teste',
  'channel': channel,
  'created_at': '2026-11-17T10:00:00Z',
  'delivered_at': deliveredAt,
});

Widget _app(ProviderContainer container, Widget child) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: BmoTheme.themeData,
        home: Scaffold(body: Center(child: child)),
      ),
    );

void main() {
  late FakeRoutinesRepository repo;
  late ProviderContainer container;

  setUp(() {
    repo = FakeRoutinesRepository();
    container = ProviderContainer(
      overrides: [
        routinesRepositoryProvider.overrideWithValue(repo),
        eventsStreamProvider.overrideWith((ref) => const Stream.empty()),
      ],
    );
    addTearDown(container.dispose);
    container.read(currentUserIdProvider.notifier).state = 1;
  });

  testWidgets('toque na presença lista os quatro estados e envia o escolhido', (
    tester,
  ) async {
    await tester.pumpWidget(_app(container, const PresenceButton()));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PresenceButton));
    await tester.pumpAndSettle();

    expect(find.text('em casa'), findsOneWidget);
    expect(find.text('voz silenciada'), findsOneWidget);
    expect(find.text('silêncio até…'), findsOneWidget);

    await tester.tap(find.text('fora'));
    await tester.pumpAndSettle();

    expect(repo.lastMode, PresenceMode.fora);
    expect(repo.lastUntil, isNull);
    expect(
      container.read(presenceControllerProvider).valueOrNull?.mode,
      PresenceMode.fora,
    );
  });

  testWidgets('badge do sino conta só as seguradas não entregues', (
    tester,
  ) async {
    repo.notifications = [
      _notification(id: 1, channel: 'segurada'),
      _notification(id: 2, channel: 'segurada'),
      _notification(
        id: 3,
        channel: 'segurada',
        deliveredAt: '2026-11-17T10:05:00Z',
      ),
      _notification(id: 4),
    ];

    await tester.pumpWidget(_app(container, const NotificationsBell()));
    await tester.pumpAndSettle();

    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.byType(NotificationsBell));
    await tester.pumpAndSettle();

    expect(find.text('Seguradas'), findsOneWidget);
    expect(find.text('Recentes'), findsOneWidget);
  });
}
