import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'device.dart';

class DevicesWsClient {
  final String _baseUrl;
  StreamSubscription<Object?>? _currentSubscription;
  WebSocketChannel? _channel;

  DevicesWsClient({required String baseUrl}) : _baseUrl = baseUrl;

  /// Abre o WebSocket de lights do bmo-server.
  ///
  /// Baseado em [StreamController] (e não em gerador `async*`): o cancel de
  /// um `async*` suspenso sobre stream silencioso só é entregue quando o
  /// stream interno emite algo — com a conexão morta (iOS em background) o
  /// cancel nunca chegaria e o socket antigo vazaria. Aqui o `onCancel`
  /// fecha subscription e sink imediatamente.
  Stream<DeviceWsMessage> connect() {
    late final StreamController<DeviceWsMessage> controller;
    controller = StreamController<DeviceWsMessage>(
      onCancel: () {
        _currentSubscription?.cancel();
        _channel?.sink.close();
      },
    );

    () async {
      try {
        final wsUrl = _baseUrl
            .replaceFirst('https://', 'wss://')
            .replaceFirst('http://', 'ws://');
        final uri = Uri.parse('$wsUrl/api/v1/lights/ws');

        final channel = _channel = WebSocketChannel.connect(uri);
        await channel.ready;
        if (controller.isClosed) {
          channel.sink.close();
          return;
        }

        _currentSubscription = channel.stream.listen(
          (data) => _handleMessage(controller, data),
          onDone: controller.close,
          onError: (Object error, StackTrace stack) {
            if (!controller.isClosed) controller.addError(error, stack);
          },
          cancelOnError: false,
        );
        // Cancel pode chegar entre o check acima e a subscription ficar
        // pronta — cobre a janela cancelando na hora.
        if (controller.isClosed) {
          _currentSubscription?.cancel();
          channel.sink.close();
          return;
        }
      } catch (error, stack) {
        if (!controller.isClosed) {
          controller.addError(error, stack);
          await controller.close();
        }
      }
    }();

    return controller.stream;
  }

  void _handleMessage(StreamController<DeviceWsMessage> controller,
      Object? data) {
    try {
      final json = jsonDecode(data as String) as Map<String, dynamic>;
      final type = json['type'] as String?;

      switch (type) {
        case 'initial_state':
          final lightsList = (json['lights'] as List<dynamic>)
              .map((e) => LightDevice.fromJson(e as Map<String, dynamic>))
              .toList();
          if (!controller.isClosed) controller.add(InitialState(lightsList));
        case 'state_update':
          final stateObj = json['state'] as Map<String, dynamic>?;
          final rawState = stateObj?['state'] as String? ?? '';
          final lightState = switch (rawState.toUpperCase()) {
            'ON' => LightState.on,
            'OFF' => LightState.off,
            _ => LightState.unknown,
          };
          if (!controller.isClosed) {
            controller.add(StateUpdate(
              deviceName: json['device'] as String? ?? '',
              newState: lightState,
              linkquality:
                  (stateObj?['linkquality'] as num?)?.toDouble() ?? 0.0,
            ));
          }
        default:
          debugPrint('DevicesWsClient: unknown message type: $type');
      }
    } catch (e) {
      debugPrint('DevicesWsClient: error parsing message: $e');
    }
  }
}
