import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'current_minute_provider.g.dart';

/// Formato compartilhado de hora (HH:mm) dos cards de relógio.
final hourFormatter = DateFormat('HH:mm');

/// Saudação por período do dia.
String greetingForHour(int hour) {
  if (hour >= 6 && hour < 12) return 'Bom dia,';
  if (hour >= 12 && hour < 18) return 'Boa tarde,';
  return 'Boa noite,';
}

/// Hora atual com granularidade de minuto, compartilhada por ClockCard e
/// pelo header mobile.
///
/// O primeiro tick é alinhado ao próximo minuto cheio (não um
/// `Timer.periodic(Duration(minutes: 1))` cru, que deriva a cada ciclo).
/// No iOS o sistema suspende o app e o Timer não sobrevive: onPause cancela,
/// onResume refresca o valor na hora e re-arma. Mesmo padrão do
/// [AppLifecycleReconnect] — o gate `kIsWeb` mantém o comportamento web
/// idêntico ao de hoje (lá onPause/onResume nem disparam).
@riverpod
class CurrentMinute extends _$CurrentMinute {
  Timer? _timer;
  late final AppLifecycleListener _listener;
  var _backgrounded = false;

  @override
  DateTime build() {
    _listener = AppLifecycleListener(
      onPause: () {
        _backgrounded = true;
        _timer?.cancel();
      },
      onResume: () {
        // iOS manda inactive → resumed também no cold start; sem flag
        // isso resetaria o timer recém-armado a cada launch.
        if (kIsWeb || !_backgrounded) return;
        _backgrounded = false;
        state = DateTime.now();
        _armTimer();
      },
    );
    ref.onDispose(() {
      _timer?.cancel();
      _listener.dispose();
    });
    _armTimer();
    return DateTime.now();
  }

  void _armTimer() {
    final now = DateTime.now();
    final nextFullMinute =
        DateTime(now.year, now.month, now.day, now.hour, now.minute)
            .add(const Duration(minutes: 1));
    _timer = Timer(nextFullMinute.difference(now), () {
      state = DateTime.now();
      _armTimer();
    });
  }
}
