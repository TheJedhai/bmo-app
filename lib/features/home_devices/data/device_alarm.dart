import '../../missions/data/models/task.dart';

enum DeviceAlarmActionType { light, scene }

extension DeviceAlarmActionTypeJson on DeviceAlarmActionType {
  String toJson() => name;

  static DeviceAlarmActionType fromJson(String value) {
    return DeviceAlarmActionType.values.firstWhere(
      (e) => e.name == value,
      orElse: () =>
          throw ArgumentError('Unknown DeviceAlarmActionType: $value'),
    );
  }
}

final class DeviceAlarm {
  final int id;
  final String name;
  final bool enabled;
  final DateTime? dueDate;
  final String? dueTime;
  final RecurrenceType? recurrenceType;
  final List<int>? recurrenceDays;
  final DeviceAlarmActionType actionType;
  final String? deviceName;
  final String? targetState;
  final int? sceneId;

  const DeviceAlarm({
    required this.id,
    required this.name,
    this.enabled = true,
    this.dueDate,
    this.dueTime,
    this.recurrenceType,
    this.recurrenceDays,
    required this.actionType,
    this.deviceName,
    this.targetState,
    this.sceneId,
  });

  factory DeviceAlarm.fromJson(Map<String, dynamic> json) {
    return DeviceAlarm(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
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
      actionType: DeviceAlarmActionTypeJson.fromJson(
        json['action_type'] as String? ?? 'light',
      ),
      deviceName: json['device_name'] as String?,
      targetState: json['target_state'] as String?,
      sceneId: json['scene_id'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'enabled': enabled,
      if (dueDate != null) 'due_date': _formatDate(dueDate!),
      if (dueTime != null) 'due_time': dueTime,
      if (recurrenceType != null)
        'recurrence_type': recurrenceType!.toJson(),
      if (recurrenceDays != null) 'recurrence_days': recurrenceDays,
      'action_type': actionType.toJson(),
      if (deviceName != null) 'device_name': deviceName,
      if (targetState != null) 'target_state': targetState,
      if (sceneId != null) 'scene_id': sceneId,
    };
  }

  @override
  String toString() =>
      'DeviceAlarm(id=$id, name="$name", enabled=$enabled, actionType=$actionType)';
}

String _formatDate(DateTime dt) {
  return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}
