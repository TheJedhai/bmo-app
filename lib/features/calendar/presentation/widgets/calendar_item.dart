import '../../data/models/calendar_event.dart' as app;
import '../../../missions/data/models/task.dart';

/// Unified type for items shown on the calendar — events from the calendar
/// backend and tasks from the missions backend merge into a single stream.
sealed class CalendarItem {
  const CalendarItem();
}

final class EventItem extends CalendarItem {
  final app.CalendarEvent event;
  const EventItem(this.event);
}

final class TaskItem extends CalendarItem {
  final Task task;
  const TaskItem(this.task);
}
