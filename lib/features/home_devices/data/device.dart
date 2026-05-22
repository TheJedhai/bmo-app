enum LightState { on, off, unknown }

final class LightDevice {
  final String name;
  final LightState state;
  final int linkquality;
  final bool online;

  const LightDevice({
    required this.name,
    required this.state,
    required this.linkquality,
    required this.online,
  });

  factory LightDevice.fromJson(Map<String, dynamic> json) {
    final rawState = json['state']?['state'] as String? ?? '';
    final state = switch (rawState.toUpperCase()) {
      'ON' => LightState.on,
      'OFF' => LightState.off,
      _ => LightState.unknown,
    };
    return LightDevice(
      name: json['name'] as String? ?? '',
      state: state,
      linkquality: (json['linkquality'] as num?)?.toInt() ?? 0,
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
  final String state;
  const StateUpdate({required this.deviceName, required this.state});
}
