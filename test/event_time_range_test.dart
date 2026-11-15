import 'package:bmo_app/core/utils/event_time_range.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Data fixa para os testes.
  final day = DateTime(2026, 8, 24);

  test('20:00–22:00 termina no mesmo dia', () {
    final r = timeRangeOnDay(day, '20:00', '22:00');
    expect(r.start, DateTime(2026, 8, 24, 20, 0));
    expect(r.end, DateTime(2026, 8, 24, 22, 0));
    expect(r.end.difference(r.start).inMinutes, 2 * 60);
  });

  test('fim igual ao início ancora no início com duração mínima', () {
    final r = timeRangeOnDay(day, '14:00', '14:00');
    expect(r.start, DateTime(2026, 8, 24, 14, 0));
    expect(r.end.difference(r.start), kMinEventVisualDuration);
  });

  test('fim antes do início não estica a grade (dado legado)', () {
    final r = timeRangeOnDay(day, '14:00', '13:00');
    expect(r.start, DateTime(2026, 8, 24, 14, 0));
    expect(r.end, DateTime(2026, 8, 24, 14, 30));
  });

  test('fim atravessando a meia-noite também não vira 23h de bloco', () {
    final r = timeRangeOnDay(day, '22:00', '02:00');
    expect(r.start, DateTime(2026, 8, 24, 22, 0));
    expect(r.end, DateTime(2026, 8, 24, 22, 30));
  });
}
