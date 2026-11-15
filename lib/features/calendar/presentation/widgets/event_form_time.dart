import 'package:flutter/material.dart';

/// Estado de horário do editor de evento.
///
/// Concentra as regras que o formulário precisa manter:
/// - evento novo com hora começa com 1 h de duração;
/// - mover o início move o fim junto, preservando a duração escolhida;
/// - mudar o fim mexe só na duração;
/// - ligar/desligar "dia todo" não toca nos horários (a duração fica);
/// - o fim precisa ser depois do início (dia todo não tem horário).
class EventTimeSelection {
  /// Duração padrão de um evento novo com hora.
  static const Duration defaultDuration = Duration(hours: 1);

  /// Último minuto representável num mesmo dia.
  static const int _lastMinuteOfDay = 23 * 60 + 59;

  TimeOfDay start;
  TimeOfDay end;
  bool allDay;

  EventTimeSelection({
    required this.start,
    required this.end,
    this.allDay = false,
  });

  /// Evento novo: sem [end] explícito, o fim é início + 1 h (limitado a 23:59).
  factory EventTimeSelection.newEvent({
    TimeOfDay start = const TimeOfDay(hour: 9, minute: 0),
    TimeOfDay? end,
    bool allDay = false,
  }) =>
      EventTimeSelection(
        start: start,
        end: end ?? _after(start, defaultDuration),
        allDay: allDay,
      );

  int get _startMinutes => start.hour * 60 + start.minute;

  int get _endMinutes => end.hour * 60 + end.minute;

  /// Duração escolhida. Um fim inválido conta como [defaultDuration], para a
  /// próxima mudança de início não colapsar o evento.
  Duration get duration {
    final minutes = _endMinutes - _startMinutes;
    return minutes > 0 ? Duration(minutes: minutes) : defaultDuration;
  }

  /// Fim precisa ser depois do início; "dia todo" não tem horário.
  bool get isValid => allDay || _endMinutes > _startMinutes;

  /// Mover o início leva o fim junto, preservando a duração.
  void moveStart(TimeOfDay value) {
    final kept = duration;
    start = value;
    end = _after(value, kept);
  }

  /// Mudar o fim altera só a duração.
  void changeEnd(TimeOfDay value) => end = value;

  /// Ligar/desligar "dia todo" preserva os horários escolhidos.
  void setAllDay(bool value) => allDay = value;

  static TimeOfDay _after(TimeOfDay from, Duration duration) {
    final total =
        (from.hour * 60 + from.minute + duration.inMinutes).clamp(0, _lastMinuteOfDay);
    return TimeOfDay(hour: total ~/ 60, minute: total % 60);
  }
}
