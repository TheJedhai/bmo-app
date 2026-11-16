// Registry da dashboard: memórias saíram dela (agora vivem no chat).

import 'package:flutter_test/flutter_test.dart';

import 'package:bmo_app/features/dashboard/dashboard_registry.dart';

void main() {
  test('dashboard não tem card de memórias', () {
    expect(
      dashboardWidgets.where((s) => s.id == 'memorias'),
      isEmpty,
    );
    expect(
      dashboardWidgets.where((s) => s.route == '/memorias'),
      isEmpty,
    );
  });
}
