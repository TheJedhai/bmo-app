import 'package:bmo_app/core/utils/recurrence_weekday.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Dias da semana na ordem do seletor (dom=1..sáb=7) e seus ISO (1=seg..7=dom).
  //      seletor  show | ISO
  const cases = <(int, int)>[
    (1, 7), // domingo
    (2, 1), // segunda
    (3, 2), // terça
    (4, 3), // quarta
    (5, 4), // quinta
    (6, 5), // sexta
    (7, 6), // sábado
  ];

  test('appDayToIso mapeia os sete dias', () {
    for (final (appDay, iso) in cases) {
      expect(appDayToIso(appDay), iso, reason: 'appDay=$appDay');
    }
  });

  test('isoToAppDay mapeia os sete dias', () {
    for (final (appDay, iso) in cases) {
      expect(isoToAppDay(iso), appDay, reason: 'iso=$iso');
    }
  });

  test('os dois sentidos são inversos (domingo incluso)', () {
    for (var iso = 1; iso <= 7; iso++) {
      expect(appDayToIso(isoToAppDay(iso)), iso);
      expect(isoToAppDay(appDayToIso(iso)), iso);
    }
  });

  // Domingo é o caso mais grave: no bug, ISO 7 (domingo) era lido como sábado.
  test('domingo mapeia para domingo nos dois sentidos', () {
    expect(isoToAppDay(7), 1);
    expect(appDayToIso(1), 7);
  });
}
