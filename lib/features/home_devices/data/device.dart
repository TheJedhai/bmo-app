enum LightState { on, off, unknown }

final class LightDevice {
  final String name;
  final LightState state;
  final double linkquality;
  final bool online;

  const LightDevice({
    required this.name,
    required this.state,
    required this.linkquality,
    required this.online,
  });

  factory LightDevice.fromJson(Map<String, dynamic> json) {
    final stateObj = json['state'] as Map<String, dynamic>?;
    final rawState = stateObj?['state'] as String? ?? '';
    final state = switch (rawState.toUpperCase()) {
      'ON' => LightState.on,
      'OFF' => LightState.off,
      _ => LightState.unknown,
    };
    return LightDevice(
      name: json['name'] as String? ?? '',
      state: state,
      linkquality: (stateObj?['linkquality'] as num?)?.toDouble() ?? 0.0,
      online: json['online'] as bool? ?? false,
    );
  }
}

sealed class DeviceWsMessage {
  const DeviceWsMessage();
}

final class InitialState extends DeviceWsMessage {
  final List<LightDevice> lights;
  const InitialState(this.lights);
}

final class StateUpdate extends DeviceWsMessage {
  final String deviceName;
  final LightState newState;
  final double linkquality;
  const StateUpdate({
    required this.deviceName,
    required this.newState,
    required this.linkquality,
  });
}
