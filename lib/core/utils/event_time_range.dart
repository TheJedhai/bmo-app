import 'package:flutter/material.dart';

/// Duração mínima visual de um evento na grade: um evento com fim inválido
/// (fim não é depois do início) aparece ancorado no horário de início com
/// esta duração, em vez de esticar a grade.
const Duration kMinEventVisualDuration = Duration(minutes: 30);

/// Combina [day] com os horários "HH:mm" ([startTime], [endTime]) num
/// [DateTimeRange] para desenhar o evento.
///
/// Regra de produto: o fim precisa ser depois do início. Dado legado com fim
/// menor ou igual ao início não quebra a grade — o evento fica no horário de
/// início com [kMinEventVisualDuration].
DateTimeRange timeRangeOnDay(DateTime day, String startTime, String endTime) {
  final start = _timeOn(day, startTime);
  final end = _timeOn(day, endTime);
  return DateTimeRange(
    start: start,
    end: end.isAfter(start) ? end : start.add(kMinEventVisualDuration),
  );
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
