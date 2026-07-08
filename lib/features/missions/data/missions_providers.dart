import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/http/client_factory.dart';
import 'missions_client.dart';
import 'missions_repository.dart';
import 'models/folder.dart';
import 'models/task.dart';

// ============================================================
// Infraestrutura
// ============================================================

final missionsClientProvider = Provider<MissionsClient>((ref) {
  return MissionsClient(
    client: ref.watch(httpClientProvider),
    baseUrl: Env.bmoServerUrl,
  );
});

final missionsRepositoryProvider = Provider<MissionsRepository>((ref) {
  return MissionsRepository(ref.read(missionsClientProvider));
});

// ============================================================
// Folders
// ============================================================

class FoldersNotifier extends AsyncNotifier<List<Folder>> {
  @override
  Future<List<Folder>> build() async {
    final repo = ref.read(missionsRepositoryProvider);
    return repo.listFolders();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    final repo = ref.read(missionsRepositoryProvider);
    state = await AsyncValue.guard(() => repo.listFolders());
  }

  Future<Folder> create(String name, {int sortOrder = 0}) async {
    final repo = ref.read(missionsRepositoryProvider);
    final folder = await repo.createFolder(name: name, sortOrder: sortOrder);
    final current = state.valueOrNull ?? const <Folder>[];
    state = AsyncData([...current, folder]);
    return folder;
  }

  Future<Folder> edit(int id, {String? name, int? sortOrder}) async {
    final repo = ref.read(missionsRepositoryProvider);
    final updated = await repo.updateFolder(id, name: name, sortOrder: sortOrder);
    final current = state.valueOrNull ?? const <Folder>[];
    state = AsyncData([
      for (final f in current)
        if (f.id == id) updated else f,
    ]);
    return updated;
  }

  Future<void> remove(int id) async {
    final repo = ref.read(missionsRepositoryProvider);
    await repo.deleteFolder(id);
    final current = state.valueOrNull ?? const <Folder>[];
    state = AsyncData(current.where((f) => f.id != id).toList());
  }
}

final foldersProvider =
    AsyncNotifierProvider<FoldersNotifier, List<Folder>>(
  FoldersNotifier.new,
);

// ============================================================
// Tasks
// ============================================================

typedef TasksFilter = ({
  String? status,
  int? folderId,
  int? parentId,
  bool includeSubtasks,
});

class TasksNotifier extends FamilyAsyncNotifier<List<Task>, TasksFilter> {
  @override
  Future<List<Task>> build(TasksFilter arg) async {
    final repo = ref.read(missionsRepositoryProvider);
    return repo.listTasks(
      status: arg.status,
      folderId: arg.folderId,
      parentId: arg.parentId,
      includeSubtasks: arg.includeSubtasks,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    final repo = ref.read(missionsRepositoryProvider);
    state = await AsyncValue.guard(() => repo.listTasks(
          status: arg.status,
          folderId: arg.folderId,
          parentId: arg.parentId,
          includeSubtasks: arg.includeSubtasks,
        ));
  }

  Future<Task> create({
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
  }) async {
    final repo = ref.read(missionsRepositoryProvider);
    final task = await repo.createTask(
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
    // If the new task matches this filter, add it to the list.
    if (_matchesFilter(task)) {
      final current = state.valueOrNull ?? const <Task>[];
      state = AsyncData([...current, task]);
    }
    return task;
  }

  Future<Task> edit(
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
    TaskStatus? taskStatus,
    int? priority,
    int? sortOrder,
    int? reminderMinutesBefore,
    bool clearReminder = false,
  }) async {
    final repo = ref.read(missionsRepositoryProvider);
    final updatedTask = await repo.updateTask(
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
      status: taskStatus,
      priority: priority,
      sortOrder: sortOrder,
      reminderMinutesBefore: reminderMinutesBefore,
      clearReminder: clearReminder,
    );
    final current = state.valueOrNull ?? const <Task>[];
    // Replace if present; if it no longer matches the filter, remove it.
    final idx = current.indexWhere((t) => t.id == id);
    if (idx != -1) {
      if (_matchesFilter(updatedTask)) {
        final updated = List<Task>.from(current);
        updated[idx] = updatedTask;
        state = AsyncData(updated);
      } else {
        state = AsyncData(current.where((t) => t.id != id).toList());
      }
    } else if (_matchesFilter(updatedTask)) {
      state = AsyncData([...current, updatedTask]);
    }
    return updatedTask;
  }

  Future<({Task completed, Task? nextOccurrence})> complete(int id) async {
    final repo = ref.read(missionsRepositoryProvider);
    final result = await repo.completeTask(id);
    await refresh();
    return result;
  }

  Future<({int deletedId, int cascadedSubtasks})> delete(int id) async {
    final repo = ref.read(missionsRepositoryProvider);
    final result = await repo.deleteTask(id);
    final current = state.valueOrNull ?? const <Task>[];
    state = AsyncData(current.where((t) => t.id != id).toList());
    return result;
  }

  /// Sends the new task order to the backend.
  /// No optimistic mutation — the SSE handler invalidates and refetches
  /// so the list stays consistent with the server state.
  Future<void> reorder(List<int> taskIds) async {
    final repo = ref.read(missionsRepositoryProvider);
    await repo.reorderTasks(taskIds);
  }

  bool _matchesFilter(Task task) {
    if (arg.status != null && arg.status != task.status.name) return false;
    if (arg.folderId != null && arg.folderId != task.folderId) return false;
    if (arg.parentId != null && arg.parentId != task.parentId) return false;
    return true;
  }
}

final tasksProvider =
    AsyncNotifierProvider.family<TasksNotifier, List<Task>, TasksFilter>(
  TasksNotifier.new,
);
