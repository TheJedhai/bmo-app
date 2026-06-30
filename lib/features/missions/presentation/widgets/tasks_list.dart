import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/bmo_theme.dart';
import '../../data/missions_client.dart';
import '../../data/missions_providers.dart';
import '../../data/models/folder.dart';
import '../../data/models/task.dart';
import '../selected_view_provider.dart';
import 'task_form_modal.dart';

enum _DueGroup { overdue, today, tomorrow, upcoming, noDue }

class TasksList extends ConsumerStatefulWidget {
  const TasksList({super.key});

  @override
  ConsumerState<TasksList> createState() => _TasksListState();
}

class _TasksListState extends ConsumerState<TasksList> {
  bool _showCompleted = false;
  final Map<int, bool> _expandedSubtasks = {};

  int? get _folderIdFromView {
    final currentView = ref.read(currentViewProvider);
    return switch (currentView) {
      FolderView(:final folderId) => folderId,
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentView = ref.watch(currentViewProvider);

    final folderId = switch (currentView) {
      FolderView(:final folderId) => folderId,
      _ => null,
    };

    final filter = (
      status: _showCompleted ? null : 'pending',
      folderId: folderId,
      parentId: 0,
      includeSubtasks: true,
    );

    final tasksAsync = ref.watch(tasksProvider(filter));
    final tasksNotifier = ref.read(tasksProvider(filter).notifier);

    return Stack(
      children: [
        Column(
          children: [
            _ToggleRow(
              showCompleted: _showCompleted,
              onChanged: (v) => setState(() => _showCompleted = v),
              theme: theme,
            ),
            const Divider(
              color: BmoColors.textMuted,
              height: 1,
            ),
            Expanded(
              child: tasksAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => _ErrorState(
                  error: e,
                  onRetry: () => tasksNotifier.refresh(),
                ),
                data: (tasks) {
                  var displayTasks = _showCompleted
                      ? tasks
                          .where((t) => t.status != TaskStatus.cancelled)
                          .toList()
                      : tasks;

                  final now = DateTime.now();
                  final today =
                      DateTime(now.year, now.month, now.day);

                  displayTasks = switch (currentView) {
                    TodayTasks() => displayTasks
                        .where((t) {
                          if (t.dueDate == null) return false;
                          final dueDay = DateTime(
                            t.dueDate!.year,
                            t.dueDate!.month,
                            t.dueDate!.day,
                          );
                          return !dueDay.isAfter(today);
                        })
                        .toList(),
                    UrgentTasks() => displayTasks
                        .where((t) => t.priority >= 1)
                        .toList(),
                    _ => displayTasks,
                  };

                  if (displayTasks.isEmpty) {
                    return _EmptyState(theme: theme);
                  }
                  final groups = _groupAndSort(displayTasks);
                  final visibleGroups = switch (currentView) {
                    TodayTasks() =>
                      <_DueGroup, List<Task>>{
                        for (final g in const [
                          _DueGroup.overdue,
                          _DueGroup.today,
                        ])
                          g: groups[g]!,
                      },
                    _ => groups,
                  };
                  return _GroupedTaskList(
                    groups: visibleGroups,
                    theme: theme,
                    expandedSubtasks: _expandedSubtasks,
                    isFolderView: currentView is FolderView,
                    onTaskTap: _openEditModal,
                    onTaskComplete: _completeTask,
                    onTaskEdit: _openEditModal,
                    onTaskMove: _moveTask,
                    onTaskDelete: _deleteTask,
                    onToggleSubtasks: _toggleSubtasks,
                    onGroupReorder: _onGroupReorder,
                  );
                },
              ),
            ),
          ],
        ),
        Positioned(
          right: 20,
          bottom: 20,
          child: _NewMissionFab(
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => TaskFormModal(
                  initialFolderId: _folderIdFromView,
                ),
              ).then((_) {
                ref.read(tasksProvider(
                  (
                    status: _showCompleted ? null : 'pending',
                    folderId: _folderIdFromView,
                    parentId: 0,
                    includeSubtasks: true,
                  ),
                ).notifier).refresh();
              });
            },
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // Task actions
  // ==========================================================

  void _openEditModal(Task task) {
    showDialog(
      context: context,
      builder: (_) => TaskFormModal(task: task),
    ).then((_) {
      ref.read(tasksProvider(
        (
          status: _showCompleted ? null : 'pending',
          folderId: _folderIdFromView,
          parentId: 0,
          includeSubtasks: true,
        ),
      ).notifier).refresh();
    });
  }

  Future<void> _completeTask(Task task) async {
    final filter = (
      status: _showCompleted ? null : 'pending',
      folderId: _folderIdFromView,
      parentId: 0,
      includeSubtasks: true,
    );
    final notifier = ref.read(tasksProvider(filter).notifier);
    try {
      await notifier.complete(task.id);
    } on MissionsApiException catch (e) {
      if (!mounted) return;
      if (e.errorCode == 'parent_blocked_by_pending_subtasks') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Conclua as subtarefas primeiro')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }
  }

  Future<void> _moveTask(Task task) async {
    final foldersAsync = ref.read(foldersProvider);
    final folders = foldersAsync.valueOrNull ?? <Folder>[];

    if (!mounted) return;

    final selected = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: BmoColors.screenBgElevated,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Mover para…',
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 11,
                color: BmoColors.textPrimary,
              ),
            ),
          ),
          ...folders.map((f) => ListTile(
                title: Text(f.name,
                    style: const TextStyle(color: BmoColors.textPrimary)),
                onTap: () => Navigator.of(ctx).pop(f.id),
              )),
          const SizedBox(height: 8),
        ],
      ),
    );

    if (selected != null && mounted) {
      final filter = (
        status: _showCompleted ? null : 'pending',
        folderId: _folderIdFromView,
        parentId: 0,
        includeSubtasks: true,
      );
      final notifier = ref.read(tasksProvider(filter).notifier);
      try {
        await notifier.edit(task.id, folderId: selected);
      } on MissionsApiException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }
  }

  Future<void> _deleteTask(Task task) async {
    final subtaskCount = task.subtasks?.length ?? 0;
    final message = subtaskCount > 0
        ? "Deletar '${task.title}'? $subtaskCount subtarefas serão deletadas também."
        : "Deletar '${task.title}'?";

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BmoColors.screenBgElevated,
        title: const Text('Deletar missão?',
            style: TextStyle(color: BmoColors.textPrimary, fontSize: 14)),
        content: Text(message,
            style: const TextStyle(color: BmoColors.textSecondary, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Deletar',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final filter = (
        status: _showCompleted ? null : 'pending',
        folderId: _folderIdFromView,
        parentId: 0,
        includeSubtasks: true,
      );
      final notifier = ref.read(tasksProvider(filter).notifier);
      try {
        await notifier.delete(task.id);
      } on MissionsApiException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }
  }

  void _toggleSubtasks(int taskId) {
    setState(() {
      _expandedSubtasks[taskId] = !(_expandedSubtasks[taskId] ?? false);
    });
  }

  Future<void> _onGroupReorder(
    _DueGroup group,
    int oldIndex,
    int newIndex,
  ) async {
    final folderId = _folderIdFromView;
    final filter = (
      status: _showCompleted ? null : 'pending',
      folderId: folderId,
      parentId: 0,
      includeSubtasks: true,
    );

    final tasksAsync = ref.read(tasksProvider(filter));
    final tasks = tasksAsync.valueOrNull;
    if (tasks == null) return;

    var displayTasks = _showCompleted
        ? tasks.where((t) => t.status != TaskStatus.cancelled).toList()
        : tasks;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final currentView = ref.read(currentViewProvider);
    displayTasks = switch (currentView) {
      TodayTasks() => displayTasks
          .where((t) {
            if (t.dueDate == null) return false;
            final dueDay = DateTime(
              t.dueDate!.year,
              t.dueDate!.month,
              t.dueDate!.day,
            );
            return !dueDay.isAfter(today);
          })
          .toList(),
      _ => displayTasks,
    };

    final groups = _groupAndSort(displayTasks);
    final groupTasks = groups[group]!;

    final reordered = List<Task>.from(groupTasks);
    final item = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, item);

    final orderedIds = reordered.map((t) => t.id).toList();

    final notifier = ref.read(tasksProvider(filter).notifier);
    try {
      await notifier.reorder(orderedIds);
    } on MissionsApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }
}

// ============================================================
// Toggle "ver concluídas"
// ============================================================

class _ToggleRow extends StatelessWidget {
  final bool showCompleted;
  final ValueChanged<bool> onChanged;
  final ThemeData theme;

  const _ToggleRow({
    required this.showCompleted,
    required this.onChanged,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            'ver concluídas',
            style: theme.textTheme.bodySmall?.copyWith(
              color: BmoColors.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: showCompleted,
              onChanged: onChanged,
              activeTrackColor: BmoColors.accentGreen,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Grouped list
// ============================================================

typedef _TaskAction = void Function(Task task);
typedef _TaskToggleExpand = void Function(int taskId);

class _GroupedTaskList extends StatelessWidget {
  final Map<_DueGroup, List<Task>> groups;
  final ThemeData theme;
  final Map<int, bool> expandedSubtasks;
  final bool isFolderView;
  final _TaskAction onTaskTap;
  final _TaskAction onTaskComplete;
  final _TaskAction onTaskEdit;
  final _TaskAction onTaskMove;
  final _TaskAction onTaskDelete;
  final _TaskToggleExpand onToggleSubtasks;
  final Future<void> Function(_DueGroup group, int oldIndex, int newIndex)?
      onGroupReorder;

  const _GroupedTaskList({
    required this.groups,
    required this.theme,
    required this.expandedSubtasks,
    this.isFolderView = false,
    required this.onTaskTap,
    required this.onTaskComplete,
    required this.onTaskEdit,
    required this.onTaskMove,
    required this.onTaskDelete,
    required this.onToggleSubtasks,
    this.onGroupReorder,
  });

  @override
  Widget build(BuildContext context) {
    final entries = groups.entries.where((e) => e.value.isNotEmpty).toList();

    if (isFolderView) {
      return _buildReorderableGroups(entries);
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: entries.fold<int>(
        0,
        (sum, e) => sum + 1 + e.value.length,
      ),
      itemBuilder: (context, index) {
        var cursor = 0;
        for (final entry in entries) {
          if (index == cursor) {
            return _GroupHeader(group: entry.key, theme: theme);
          }
          cursor++;
          final taskIndex = index - cursor;
          if (taskIndex < entry.value.length) {
            final task = entry.value[taskIndex];
            return _buildTaskBlock(task);
          }
          cursor += entry.value.length;
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildReorderableGroups(
    List<MapEntry<_DueGroup, List<Task>>> entries,
  ) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 80),
      children: [
        for (final entry in entries) ...[
          _GroupHeader(group: entry.key, theme: theme),
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            proxyDecorator: (child, index, animation) {
              return AnimatedBuilder(
                animation: animation,
                builder: (context, child) => Material(
                  color: Colors.transparent,
                  elevation: 4,
                  child: child,
                ),
                child: child,
              );
            },
            onReorder: (oldIndex, newIndex) =>
                onGroupReorder?.call(entry.key, oldIndex, newIndex),
            children: [
              for (var i = 0; i < entry.value.length; i++)
                _buildTaskBlock(
                  entry.value[i],
                  dragIndex: i,
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildTaskBlock(
    Task task, {
    int dragIndex = 0,
  }) {
    final isExpanded = expandedSubtasks[task.id] ?? false;
    final hasSubtasks = task.subtasks != null && task.subtasks!.isNotEmpty;
    return Column(
      key: ValueKey(task.id),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TaskItem(
          task: task,
          theme: theme,
          isFolderView: isFolderView,
          dragIndex: dragIndex,
          onTap: () => onTaskTap(task),
          onComplete: () => onTaskComplete(task),
          onEdit: () => onTaskEdit(task),
          onMove: () => onTaskMove(task),
          onDelete: () => onTaskDelete(task),
          hasSubtasks: hasSubtasks,
          isExpanded: isExpanded,
          onToggleExpand: () => onToggleSubtasks(task.id),
        ),
        if (hasSubtasks && isExpanded)
          ...task.subtasks!.map((sub) => _TaskItem(
                task: sub,
                theme: theme,
                isSubtask: true,
                onTap: () => onTaskTap(sub),
                onComplete: () => onTaskComplete(sub),
                onEdit: () => onTaskEdit(sub),
                onDelete: () => onTaskDelete(sub),
                hasSubtasks: false,
                isExpanded: false,
              )),
      ],
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final _DueGroup group;
  final ThemeData theme;

  const _GroupHeader({required this.group, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        _groupLabel(group),
        style: theme.textTheme.labelMedium?.copyWith(
          color: BmoColors.accentYellow,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

String _groupLabel(_DueGroup group) => switch (group) {
      _DueGroup.overdue => 'Vencidas',
      _DueGroup.today => 'Hoje',
      _DueGroup.tomorrow => 'Amanhã',
      _DueGroup.upcoming => 'Em breve',
      _DueGroup.noDue => 'Sem prazo',
    };

// ============================================================
// Task item
// ============================================================

class _TaskItem extends StatelessWidget {
  final Task task;
  final ThemeData theme;
  final bool isSubtask;
  final bool hasSubtasks;
  final bool isExpanded;
  final bool isFolderView;
  final int dragIndex;
  final VoidCallback? onToggleExpand;
  final VoidCallback? onTap;
  final VoidCallback? onComplete;
  final VoidCallback? onEdit;
  final VoidCallback? onMove;
  final VoidCallback? onDelete;

  const _TaskItem({
    required this.task,
    required this.theme,
    this.isSubtask = false,
    this.hasSubtasks = false,
    this.isExpanded = false,
    this.isFolderView = false,
    this.dragIndex = 0,
    this.onToggleExpand,
    this.onTap,
    this.onComplete,
    this.onEdit,
    this.onMove,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dueText = _formatDueDate(task.dueDate, task.dueTime);
    final dueColor = _dueColor(task.dueDate);

    return Padding(
      padding: EdgeInsets.only(
        left: isSubtask ? 36 : 12,
        right: 4,
        top: 2,
        bottom: 2,
      ),
      child: Row(
        children: [
          // Drag handle (FolderView only, root tasks only)
          if (isFolderView && !isSubtask)
            ReorderableDragStartListener(
              index: dragIndex,
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(
                  Icons.drag_handle,
                  size: 18,
                  color: BmoColors.textMuted,
                ),
              ),
            ),
          // Checkbox
          SizedBox(
            width: 30,
            height: 30,
            child: Checkbox(
              value: task.status == TaskStatus.done,
              onChanged: (_) => onComplete?.call(),
              fillColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return BmoColors.accentGreen;
                }
                return null;
              }),
              checkColor: BmoColors.screenBg,
              side: BorderSide(
                color: BmoColors.textMuted.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
          ),
          // Task body (tap target)
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: BmoColors.textPrimary,
                        decoration: task.status == TaskStatus.done
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (task.dueDate != null) ...[
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 12,
                            color: dueColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            dueText,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: dueColor,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        if (task.recurrenceType != null) ...[
                          Icon(
                            Icons.repeat,
                            size: 12,
                            color: BmoColors.accentYellow,
                          ),
                          const SizedBox(width: 10),
                        ],
                        if (task.reminderMinutesBefore != null) ...[
                          Icon(
                            Icons.notifications_outlined,
                            size: 12,
                            color: BmoColors.textMuted,
                          ),
                          const SizedBox(width: 10),
                        ],
                        if (task.priority > 0)
                          Icon(
                            Icons.flag,
                            size: 12,
                            color: _priorityColor(task.priority),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Chevron / 3-dot menu
          if (hasSubtasks)
            GestureDetector(
              onTap: onToggleExpand,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  isExpanded ? Icons.expand_more : Icons.chevron_right,
                  size: 20,
                  color: BmoColors.textMuted,
                ),
              ),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert,
                size: 18, color: BmoColors.textMuted),
            color: BmoColors.screenBgElevated,
            onSelected: (v) {
              switch (v) {
                case 'edit':
                  onEdit?.call();
                case 'move':
                  onMove?.call();
                case 'delete':
                  onDelete?.call();
              }
            },
            itemBuilder: (_) {
              final items = <PopupMenuEntry<String>>[
                const PopupMenuItem(value: 'edit', child: Text('Editar')),
              ];
              if (!isSubtask) {
                items.add(const PopupMenuItem(
                    value: 'move', child: Text('Mover para…')));
              }
              items.add(const PopupMenuItem(
                  value: 'delete', child: Text('Deletar')));
              return items;
            },
          ),
        ],
      ),
    );
  }
}

// ============================================================
// FAB "Nova missão"
// ============================================================

class _NewMissionFab extends StatelessWidget {
  final VoidCallback onPressed;

  const _NewMissionFab({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      backgroundColor: BmoColors.accentGreen,
      foregroundColor: BmoColors.screenBg,
      onPressed: onPressed,
      child: const Icon(Icons.add),
    );
  }
}

// ============================================================
// Error / Empty states
// ============================================================

class _ErrorState extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 32),
            const SizedBox(height: 8),
            Text(
              'falha ao carregar',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.redAccent,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: BmoColors.textMuted,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onRetry,
              child: const Text('tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final ThemeData theme;

  const _EmptyState({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, size: 48, color: BmoColors.textMuted),
          const SizedBox(height: 12),
          Text(
            'Nada por aqui.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: BmoColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Grouping & sorting
// ============================================================

Map<_DueGroup, List<Task>> _groupAndSort(List<Task> tasks) {
  final today = DateTime.now();
  final todayDate = DateTime(today.year, today.month, today.day);
  final groups = <_DueGroup, List<Task>>{
    for (final g in _DueGroup.values) g: <Task>[],
  };

  for (final task in tasks) {
    final group = _dueGroupFor(task.dueDate, todayDate);
    groups[group]!.add(task);
  }

  for (final g in _DueGroup.values) {
    groups[g]!.sort(_taskSort);
  }

  return groups;
}

_DueGroup _dueGroupFor(DateTime? dueDate, DateTime todayDate) {
  if (dueDate == null) return _DueGroup.noDue;
  final d = DateTime(dueDate.year, dueDate.month, dueDate.day);
  if (d.isBefore(todayDate)) return _DueGroup.overdue;
  if (d == todayDate) return _DueGroup.today;
  if (d == todayDate.add(const Duration(days: 1))) return _DueGroup.tomorrow;
  return _DueGroup.upcoming;
}

int _taskSort(Task a, Task b) {
  // sortOrder asc
  final s = a.sortOrder.compareTo(b.sortOrder);
  if (s != 0) return s;
  // dueTime asc, nulls last
  final aTime = _timeToMinutes(a.dueTime);
  final bTime = _timeToMinutes(b.dueTime);
  if (aTime != null && bTime != null) {
    final t = aTime.compareTo(bTime);
    if (t != 0) return t;
  }
  if (aTime != null && bTime == null) return -1;
  if (aTime == null && bTime != null) return 1;
  // createdAt asc
  return a.createdAt.compareTo(b.createdAt);
}

int? _timeToMinutes(String? time) {
  if (time == null) return null;
  final parts = time.split(':');
  if (parts.length < 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  return h * 60 + m;
}

// ============================================================
// Formatting helpers
// ============================================================

String _formatDueDate(DateTime? dueDate, String? dueTime) {
  if (dueDate == null) return '';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
  final diff = dueDay.difference(today).inDays;

  String label;
  if (diff == 0) {
    label = 'hoje';
  } else if (diff == 1) {
    label = 'amanhã';
  } else if (diff == -1) {
    label = 'ontem';
  } else {
    label =
        '${dueDate.day.toString().padLeft(2, '0')}/${dueDate.month.toString().padLeft(2, '0')}';
  }

  if (dueTime != null) {
    label += ' $dueTime';
  }
  return label;
}

Color _dueColor(DateTime? dueDate) {
  if (dueDate == null) return BmoColors.textSecondary;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
  if (dueDay.isBefore(today)) return Colors.redAccent;
  if (dueDay == today) return BmoColors.accentYellow;
  return BmoColors.textSecondary;
}

Color _priorityColor(int priority) {
  if (priority >= 2) return Colors.redAccent;
  if (priority == 1) return BmoColors.accentYellow;
  return BmoColors.textMuted;
}
