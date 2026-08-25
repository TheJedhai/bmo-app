import 'package:bmo_app/features/calendar/data/calendar_providers.dart';
import 'package:bmo_app/features/calendar/presentation/widgets/calendar_item.dart';
import 'package:bmo_app/features/calendar/presentation/widgets/kalender_events.dart';
import 'package:bmo_app/features/missions/data/models/task.dart';
import 'package:flutter_test/flutter_test.dart';

Task _task({
  required int id,
  required DateTime? dueDate,
  String? dueTime,
  TaskStatus status = TaskStatus.pending,
}) =>
    Task(
      id: id,
      title: 'T$id',
      dueDate: dueDate,
      dueTime: dueTime,
      folderId: 0,
      status: status,
      priority: 0,
      sortOrder: 0,
      createdAt: DateTime(2020),
      updatedAt: DateTime(2020),
    );

// Todas as datas dos testes são relativas a DateTime.now() — nunca absolutas —
// para que a regra ("anterior a hoje") valha em qualquer dia em que o teste rode.
void main() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final monthsAgo = today.subtract(const Duration(days: 90));

  group('Task.isOverdue', () {
    test('pendente vencida há meses é atrasada', () {
      expect(_task(id: 1, dueDate: monthsAgo).isOverdue, isTrue);
    });

    test('pendente com vencimento hoje não é atrasada', () {
      expect(_task(id: 2, dueDate: today).isOverdue, isFalse);
    });

    test('pendente com vencimento futuro não é atrasada', () {
      expect(
        _task(id: 3, dueDate: today.add(const Duration(days: 10))).isOverdue,
        isFalse,
      );
    });

    test('concluída vencida não é atrasada (não rola para hoje)', () {
      expect(
        _task(id: 4, dueDate: monthsAgo, status: TaskStatus.done).isOverdue,
        isFalse,
      );
    });

    test('pendente sem data de vencimento não é atrasada', () {
      expect(_task(id: 5, dueDate: null).isOverdue, isFalse);
    });
  });

  group('Conversão para o calendário', () {
    test('atrasada meses atrás aparece em hoje, dia inteiro, sem hora', () {
      final ke = toKalenderEvents([
        TaskItem(_task(id: 1, dueDate: monthsAgo, dueTime: '09:00')),
      ]).single;

      expect(ke.isOverdueTask, isTrue);
      expect(ke.allDay, isTrue); // faixa de dia inteiro, mesmo com horário
      expect(ke.startTime, isNull); // horário original descartado
      expect(ke.start.toLocal(), today); // posicionada em HOJE
      expect(ke.end.toLocal(), today.add(const Duration(days: 1)));
      expect(ke.start.toLocal(), isNot(monthsAgo)); // nunca na data original
    });

    test('tarefa de hoje sem horário continua aparecendo normalmente', () {
      final ke = toKalenderEvents([
        TaskItem(_task(id: 2, dueDate: today)),
      ]).single;

      expect(ke.isOverdueTask, isFalse);
      expect(ke.allDay, isTrue);
      expect(ke.startTime, isNull);
      expect(ke.start.toLocal(), today);
    });

    test('tarefa de hoje com horário continua no slot horário', () {
      final ke = toKalenderEvents([
        TaskItem(_task(id: 3, dueDate: today, dueTime: '14:30')),
      ]).single;

      expect(ke.isOverdueTask, isFalse);
      expect(ke.allDay, isFalse); // tem horário → slot de hora
      expect(ke.startTime, '14:30');
      expect(ke.start.toLocal(), DateTime(today.year, today.month, today.day, 14, 30));
    });

    test('concluída (ainda que vencida) não rola para hoje', () {
      // A busca do provider usa status=pending, então concluída nem chega aqui.
      // Se chegasse, não é tratada como atrasada: fica no dia de vencimento.
      final ke = toKalenderEvents([
        TaskItem(_task(id: 4, dueDate: monthsAgo, status: TaskStatus.done)),
      ]).single;

      expect(ke.isOverdueTask, isFalse);
      expect(ke.start.toLocal(), monthsAgo); // no dia original, não hoje
      expect(ke.start.toLocal(), isNot(today));
    });
  });

  group('Gate do mês (navegação)', () {
    test('mês atual contém hoje → atrasadas entram', () {
      expect(todayInTaskMonth((year: now.year, month: now.month), now), isTrue);
    });

    test('mês que não contém hoje → atrasadas não entram', () {
      final other = now.month == 12
          ? (year: now.year + 1, month: 1)
          : (year: now.year, month: now.month + 1);
      expect(todayInTaskMonth(other, now), isFalse);
    });
  });

  group('Merge sem duplicação', () {
    test('tarefa nos dois resultados aparece uma vez só', () {
      final a = _task(id: 10, dueDate: today.subtract(const Duration(days: 1)));
      final b = _task(id: 11, dueDate: today.subtract(const Duration(days: 4)));
      final merged = mergeOverdueTasks([a, b], [b, a]);
      expect(merged.map((t) => t.id).toList(), [10, 11]);
    });
  });
}
