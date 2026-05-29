import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'device.dart';

class DevicesWsClient {
  final String _baseUrl;

  DevicesWsClient({required String baseUrl}) : _baseUrl = baseUrl;

  Stream<DeviceWsMessage> connect() async* {
    final wsUrl = _baseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
    final uri = Uri.parse('$wsUrl/api/v1/lights/ws');

    final channel = WebSocketChannel.connect(uri);
    await channel.ready;

    await for (final data in channel.stream) {
      try {
        final json = jsonDecode(data as String) as Map<String, dynamic>;
        final type = json['type'] as String?;

        switch (type) {
          case 'initial_state':
            final lightsList = (json['lights'] as List<dynamic>)
                .map((e) => LightDevice.fromJson(e as Map<String, dynamic>))
                .toList();
            yield InitialState(lightsList);
          case 'state_update':
            final stateObj = json['state'] as Map<String, dynamic>?;
            final rawState = stateObj?['state'] as String? ?? '';
            final lightState = switch (rawState.toUpperCase()) {
              'ON' => LightState.on,
              'OFF' => LightState.off,
              _ => LightState.unknown,
            };
            yield StateUpdate(
              deviceName: json['device'] as String? ?? '',
              newState: lightState,
              linkquality:
                  (stateObj?['linkquality'] as num?)?.toDouble() ?? 0.0,
            );
          default:
            debugPrint('DevicesWsClient: unknown message type: $type');
        }
      } catch (e) {
        debugPrint('DevicesWsClient: error parsing message: $e');
      }
    }
  }
}
