import 'models/folder.dart';
import 'models/task.dart';
import 'missions_client.dart';

/// Thin wrapper over [MissionsClient]. Exists so the architecture is ready
/// for future caching, offline support, or persistence layers.
class MissionsRepository {
  final MissionsClient _client;

  MissionsRepository(this._client);

  Future<List<Folder>> listFolders() => _client.listFolders();

  Future<Folder> createFolder({required String name, int sortOrder = 0}) =>
      _client.createFolder(name: name, sortOrder: sortOrder);

  Future<Folder> updateFolder(int id, {String? name, int? sortOrder}) =>
      _client.updateFolder(id, name: name, sortOrder: sortOrder);

  Future<List<Task>> listTasks({
    String? status,
    int? folderId,
    int? parentId,
    DateTime? dueBefore,
    DateTime? dueAfter,
    bool includeSubtasks = false,
  }) =>
      _client.listTasks(
        status: status,
        folderId: folderId,
        parentId: parentId,
        dueBefore: dueBefore,
        dueAfter: dueAfter,
        includeSubtasks: includeSubtasks,
      );

  Future<Task> getTask(int id) => _client.getTask(id);

  Future<Task> createTask({
    required String title,
    required int folderId,
    String? notes,
    DateTime? dueDate,
    String? dueTime,
    RecurrenceType? recurrenceType,
    List<int>? recurrenceDays,
    int? parentId,
    TaskStatus? status,
    int? priority,
    int? sortOrder,
    int? reminderMinutesBefore,
  }) =>
      _client.createTask(
        title: title,
        folderId: folderId,
        notes: notes,
        dueDate: dueDate,
        dueTime: dueTime,
        recurrenceType: recurrenceType,
        recurrenceDays: recurrenceDays,
        parentId: parentId,
        status: status,
        priority: priority,
        sortOrder: sortOrder,
        reminderMinutesBefore: reminderMinutesBefore,
      );

  Future<Task> updateTask(
    int id, {
    String? title,
    String? notes,
    DateTime? dueDate,
    bool clearDueDate = false,
    String? dueTime,
    bool clearDueTime = false,
    RecurrenceType? recurrenceType,
    bool clearRecurrence = false,
    List<int>? recurrenceDays,
    int? folderId,
    int? parentId,
    TaskStatus? status,
    int? priority,
    int? sortOrder,
    int? reminderMinutesBefore,
    bool clearReminder = false,
  }) =>
      _client.updateTask(
        id,
        title: title,
        notes: notes,
        dueDate: dueDate,
        clearDueDate: clearDueDate,
        dueTime: dueTime,
        clearDueTime: clearDueTime,
        recurrenceType: recurrenceType,
        clearRecurrence: clearRecurrence,
        recurrenceDays: recurrenceDays,
        folderId: folderId,
        parentId: parentId,
        status: status,
        priority: priority,
        sortOrder: sortOrder,
        reminderMinutesBefore: reminderMinutesBefore,
        clearReminder: clearReminder,
      );

  Future<({Task completed, Task? nextOccurrence})> completeTask(int id) =>
      _client.completeTask(id);

  Future<({int deletedId, int cascadedSubtasks})> deleteTask(int id) =>
      _client.deleteTask(id);
}
