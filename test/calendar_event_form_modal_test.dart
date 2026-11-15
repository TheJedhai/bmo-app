// Editor de evento: fim inválido aparece no campo e bloqueia salvar; evento
// novo já vem com fim = início + 1 h.
//
// Run:
//   flutter test test/calendar_event_form_modal_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bmo_app/features/calendar/data/calendar_providers.dart';
import 'package:bmo_app/features/calendar/data/models/calendar.dart';
import 'package:bmo_app/features/calendar/data/models/calendar_event.dart';
import 'package:bmo_app/features/calendar/presentation/widgets/event_form_modal.dart';

class FakeCalendars extends CalendarsNotifier {
  @override
  Future<List<Calendar>> build() async => const [
        Calendar(
          id: 1,
          name: 'Pessoal',
          color: '#8BC9A3',
          type: 'personal',
          isDefault: true,
        ),
      ];
}

Future<void> _openForm(WidgetTester tester, {CalendarEvent? event}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [calendarsProvider.overrideWith(FakeCalendars.new)],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showEventFormModal(context, event: event),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

CalendarEvent _event({String? start, String? end, bool allDay = false}) =>
    CalendarEvent(
      id: 7,
      calendarId: 1,
      title: 'Existente',
      occurrenceDate: DateTime(2026, 8, 24),
      startTime: start,
      endTime: end,
      allDay: allDay,
    );

/// O botão de salvar fica no fim do ListView: rola até ele antes de ler.
Future<ElevatedButton> _saveButton(WidgetTester tester, String label) async {
  final finder = find.widgetWithText(ElevatedButton, label);
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  return tester.widget<ElevatedButton>(finder);
}

void main() {
  testWidgets('evento novo com hora vem com fim = início + 1 h',
      (tester) async {
    await _openForm(tester);

    expect(find.text('09:00'), findsOneWidget);
    expect(find.text('10:00'), findsOneWidget);
    expect((await _saveButton(tester, 'Criar evento')).onPressed, isNotNull);
  });

  testWidgets('evento existente com fim <= início mostra erro e trava salvar',
      (tester) async {
    await _openForm(tester, event: _event(start: '10:00', end: '09:00'));

    expect(find.text('o fim precisa ser depois do início'), findsOneWidget);
    expect(
      (await _saveButton(tester, 'Salvar alterações')).onPressed,
      isNull,
    );
  });

  testWidgets('evento dia todo não tem erro de horário', (tester) async {
    await _openForm(
      tester,
      event: _event(start: '10:00', end: '09:00', allDay: true),
    );

    expect(find.text('o fim precisa ser depois do início'), findsNothing);
    expect(
      (await _saveButton(tester, 'Salvar alterações')).onPressed,
      isNotNull,
    );
  });
}
