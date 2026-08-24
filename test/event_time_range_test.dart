import 'package:bmo_app/core/utils/event_time_range.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Data fixa para os testes — o problema original era o fim montado no MESMO
  // dia do início quando end_time atravessa a meia-noite.
  final day = DateTime(2026, 8, 24);

  test('22:00–02:00 termina no dia seguinte (4h)', () {
    final r = timeRangeOnDay(day, '22:00', '02:00');
    expect(r.start, DateTime(2026, 8, 24, 22, 0));
    expect(r.end, DateTime(2026, 8, 25, 2, 0));
    expect(r.end.difference(r.start).inMinutes, 4 * 60);
  });

  test('20:00–22:00 termina no mesmo dia', () {
    final r = timeRangeOnDay(day, '20:00', '22:00');
    expect(r.start, DateTime(2026, 8, 24, 20, 0));
    expect(r.end, DateTime(2026, 8, 24, 22, 0));
    expect(r.end.difference(r.start).inMinutes, 2 * 60);
  });

  test('23:30–00:30 mantém início no dia original e fim no seguinte', () {
    final r = timeRangeOnDay(day, '23:30', '00:30');
    expect(r.start, DateTime(2026, 8, 24, 23, 30));
    expect(r.end, DateTime(2026, 8, 25, 0, 30));
  });
}
