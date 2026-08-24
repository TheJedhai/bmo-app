import 'package:flutter/material.dart';

/// Combina [day] com os horários "HH:mm" ([startTime], [endTime]) num
/// [DateTimeRange]. Regra de produto: um evento dura no máximo 1 dia; se
/// [endTime] for anterior a [startTime], o fim cai no dia seguinte.
///
/// Ponto único da convenção de fim após meia-noite — mesmo espírito do par
/// [appDayToIso]/[isoToAppDay]. Reaparece no widget iOS, exportação e
/// lembretes. Ao montar um intervalo a partir de `start_time`/`end_time` do
/// backend, use esta função em vez de aritmética solta nos builders.
DateTimeRange timeRangeOnDay(DateTime day, String startTime, String endTime) {
  final start = _timeOn(day, startTime);
  var end = _timeOn(day, endTime);
  if (end.isBefore(start)) {
    end = end.add(const Duration(days: 1));
  }
  return DateTimeRange(start: start, end: end);
}

DateTime _timeOn(DateTime day, String time) {
  final parts = time.split(':');
  return DateTime(
    day.year,
    day.month,
    day.day,
    int.tryParse(parts[0]) ?? 0,
    int.tryParse(parts[1]) ?? 0,
  );
}
