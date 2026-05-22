import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'device.dart';

class DevicesWsClient {
  final String _baseUrl;
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;

  final StreamController<DeviceWsMessage> _controller =
      StreamController<DeviceWsMessage>.broadcast();

  DevicesWsClient({required String baseUrl}) : _baseUrl = baseUrl;

  Stream<DeviceWsMessage> get stream => _controller.stream;

  Future<void> connect() async {
    final wsUrl = _baseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
    final uri = Uri.parse('$wsUrl/api/v1/lights/ws');

    _channel = WebSocketChannel.connect(uri);
    await _channel!.ready;

    _subscription?.cancel();
    _subscription = _channel!.stream.listen(
      (data) {
        try {
          final json = jsonDecode(data as String) as Map<String, dynamic>;
          final type = json['type'] as String?;

          switch (type) {
            case 'initial_state':
              final lightsList = (json['lights'] as List<dynamic>)
                  .map((e) => LightDevice.fromJson(e as Map<String, dynamic>))
                  .toList();
              _controller.add(InitialState(lightsList));
            case 'state_update':
              _controller.add(StateUpdate(
                deviceName: json['device'] as String? ?? '',
                state: json['state'] as String? ?? '',
              ));
            default:
              debugPrint('DevicesWsClient: unknown message type: $type');
          }
        } catch (e) {
          debugPrint('DevicesWsClient: error parsing message: $e');
        }
      },
      onError: (error) {
        debugPrint('DevicesWsClient: WS error: $error');
        _controller.addError(error);
      },
      onDone: () {
        debugPrint('DevicesWsClient: WS closed');
      },
    );
  }

  Future<void> close() async {
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
    await _controller.close();
  }
}
