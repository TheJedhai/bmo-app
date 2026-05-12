import 'package:flutter/material.dart';

enum RecurrenceType { daily, weekly, monthly }

extension RecurrenceTypeJson on RecurrenceType {
  String toJson() => name;

  static RecurrenceType? fromJson(String? value) {
    if (value == null) return null;
    return RecurrenceType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => throw ArgumentError('Unknown RecurrenceType: $value'),
    );
  }
}

enum TaskStatus { pending, done, cancelled }

extension TaskStatusJson on TaskStatus {
  String toJson() => name;

  static TaskStatus fromJson(String value) {
    return TaskStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => throw ArgumentError('Unknown TaskStatus: $value'),
    );
  }
}

final class Task {
  final int id;
  final String title;
  final String? notes;
  final DateTime? dueDate;
  final String? dueTime;
  final RecurrenceType? recurrenceType;
  final List<int>? recurrenceDays;
  final int folderId;
  final int? parentId;
  final TaskStatus status;
  final int priority;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  final List<Task>? subtasks;

  const Task({
    required this.id,
    required this.title,
    this.notes,
    this.dueDate,
    this.dueTime,
    this.recurrenceType,
    this.recurrenceDays,
    required this.folderId,
    this.parentId,
    required this.status,
    required this.priority,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
    this.subtasks,
  });

  TimeOfDay? get dueTimeOfDay {
    if (dueTime == null) return null;
    final parts = dueTime!.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      notes: json['notes'] as String?,
      dueDate: json['due_date'] is String
          ? DateTime.tryParse(json['due_date'] as String)
          : null,
      dueTime: json['due_time'] as String?,
      recurrenceType: RecurrenceTypeJson.fromJson(
        json['recurrence_type'] as String?,
      ),
      recurrenceDays: (json['recurrence_days'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList(),
      folderId: json['folder_id'] as int? ?? 0,
      parentId: json['parent_id'] as int?,
      status: TaskStatusJson.fromJson(
        json['status'] as String? ?? 'pending',
      ),
      priority: json['priority'] as int? ?? 0,
      sortOrder: json['sort_order'] as int? ?? 0,
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
      completedAt: json['completed_at'] is String
          ? DateTime.tryParse(json['completed_at'] as String)
          : null,
      subtasks: (json['subtasks'] as List<dynamic>?)
          ?.map((e) => Task.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      if (notes != null) 'notes': notes,
      if (dueDate != null) 'due_date': _formatDate(dueDate!),
      if (dueTime != null) 'due_time': dueTime,
      if (recurrenceType != null)
        'recurrence_type': recurrenceType!.toJson(),
      if (recurrenceDays != null) 'recurrence_days': recurrenceDays,
      'folder_id': folderId,
      if (parentId != null) 'parent_id': parentId,
      'status': status.toJson(),
      'priority': priority,
      'sort_order': sortOrder,
      'created_at': _formatDateTime(createdAt),
      'updated_at': _formatDateTime(updatedAt),
      if (completedAt != null) 'completed_at': _formatDateTime(completedAt!),
      if (subtasks != null)
        'subtasks': subtasks!.map((t) => t.toJson()).toList(),
    };
  }

  @override
  String toString() => 'Task(id=$id, title="$title", status=$status)';
}

DateTime _parseDateTime(dynamic value) {
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value) ?? DateTime.now();
  }
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(
      (value * 1000).toInt(),
      isUtc: true,
    );
  }
  return DateTime.now();
}

String _formatDateTime(DateTime dt) => dt.toUtc().toIso8601String();

String _formatDate(DateTime dt) {
  return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}
