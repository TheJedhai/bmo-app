final class DevicePosition {
  final String deviceName;
  final double x; // 0-100 percentage
  final double y; // 0-100 percentage

  const DevicePosition({
    required this.deviceName,
    required this.x,
    required this.y,
  });

  factory DevicePosition.fromJson(Map<String, dynamic> json) {
    return DevicePosition(
      deviceName: json['deviceName'] as String? ?? '',
      x: (json['x'] as num?)?.toDouble() ?? 50,
      y: (json['y'] as num?)?.toDouble() ?? 50,
    );
  }

  Map<String, dynamic> toJson() => {
        'deviceName': deviceName,
        'x': x,
        'y': y,
      };
}
