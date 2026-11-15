import 'package:bmo_app/features/calendar/presentation/widgets/event_form_time.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('evento novo com hora termina 1 h depois do início', () {
    final t = EventTimeSelection.newEvent(
      start: const TimeOfDay(hour: 9, minute: 0),
    );
    expect(t.end, const TimeOfDay(hour: 10, minute: 0));
    expect(t.isValid, isTrue);
  });

  test('fim padrão respeita o fim do dia (23:30 → 23:59)', () {
    final t = EventTimeSelection.newEvent(
      start: const TimeOfDay(hour: 23, minute: 30),
    );
    expect(t.end, const TimeOfDay(hour: 23, minute: 59));
    expect(t.isValid, isTrue);
  });

  test('mover o início preserva a duração', () {
    final t = EventTimeSelection(
      start: const TimeOfDay(hour: 9, minute: 0),
      end: const TimeOfDay(hour: 11, minute: 30),
    );
    t.moveStart(const TimeOfDay(hour: 14, minute: 0));
    expect(t.start, const TimeOfDay(hour: 14, minute: 0));
    expect(t.end, const TimeOfDay(hour: 16, minute: 30));
    expect(t.duration, const Duration(hours: 2, minutes: 30));
    expect(t.isValid, isTrue);
  });

  test('mover o início perto da meia-noite limita o fim a 23:59', () {
    final t = EventTimeSelection(
      start: const TimeOfDay(hour: 9, minute: 0),
      end: const TimeOfDay(hour: 11, minute: 0),
    );
    t.moveStart(const TimeOfDay(hour: 23, minute: 0));
    expect(t.end, const TimeOfDay(hour: 23, minute: 59));
    expect(t.isValid, isTrue);
  });

  test('mudar o fim muda só a duração', () {
    final t = EventTimeSelection(
      start: const TimeOfDay(hour: 9, minute: 0),
      end: const TimeOfDay(hour: 10, minute: 0),
    );
    t.changeEnd(const TimeOfDay(hour: 12, minute: 15));
    expect(t.start, const TimeOfDay(hour: 9, minute: 0));
    expect(t.duration, const Duration(hours: 3, minutes: 15));
    expect(t.isValid, isTrue);
  });

  test('fim menor ou igual ao início é inválido (não corrige em silêncio)',
      () {
    final t = EventTimeSelection(
      start: const TimeOfDay(hour: 10, minute: 0),
      end: const TimeOfDay(hour: 9, minute: 0),
    );
    expect(t.isValid, isFalse);
    // Fim igual também é inválido.
    t.changeEnd(const TimeOfDay(hour: 10, minute: 0));
    expect(t.isValid, isFalse);
    // E o horário escolhido não foi ajustado por baixo.
    expect(t.end, const TimeOfDay(hour: 10, minute: 0));
  });

  test('alternar dia todo preserva a duração escolhida', () {
    final t = EventTimeSelection(
      start: const TimeOfDay(hour: 9, minute: 0),
      end: const TimeOfDay(hour: 12, minute: 0),
    );
    t.setAllDay(true);
    expect(t.isValid, isTrue); // dia todo dispensa horário
    t.setAllDay(false);
    expect(t.start, const TimeOfDay(hour: 9, minute: 0));
    expect(t.end, const TimeOfDay(hour: 12, minute: 0));
    expect(t.duration, const Duration(hours: 3));
  });
}
