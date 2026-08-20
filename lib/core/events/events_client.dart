import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class EventsClient {
  final http.Client _client;
  final String _baseUrl;
  StreamSubscription<String>? _currentSubscription;

  EventsClient({required http.Client client, required String baseUrl})
      : _client = client,
        _baseUrl = baseUrl;

  /// Abre o stream SSE do bmo-server.
  ///
  /// Baseado em [StreamController] (e não em gerador `async*` com `yield*`):
  /// o cancel de um `async*` suspenso sobre stream silencioso só é entregue
  /// quando o stream interno emite algo — com a conexão morta (iOS em
  /// background) o cancel nunca chegaria e a conexão antiga vazaria. Aqui o
  /// `onCancel` cancela a subscription HTTP imediatamente.
  Stream<Map<String, dynamic>> connect() {
    late final StreamController<Map<String, dynamic>> controller;
    controller = StreamController<Map<String, dynamic>>(
      onCancel: () => _currentSubscription?.cancel(),
    );

    () async {
      try {
        final request =
            http.Request('GET', Uri.parse('$_baseUrl/api/v1/stream'));
        request.headers['Accept'] = 'text/event-stream';

        final streamedResponse = await _client.send(request);
        if (controller.isClosed) {
          // Cancelado durante o send: aborta a resposta recém-chegada.
          streamedResponse.stream.listen((_) {}, onError: (_, _) {}).cancel();
          return;
        }
        if (streamedResponse.statusCode != 200) {
          final body = await streamedResponse.stream.bytesToString();
          if (!controller.isClosed) {
            controller.addError(
                EventsConnectionException(streamedResponse.statusCode, body));
            await controller.close();
          }
          return;
        }

        _currentSubscription = streamedResponse.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(
              (line) {
                if (!_isDataLine(line)) return;
                final event = _parseDataLine(line);
                if (event != null && !controller.isClosed) {
                  controller.add(event);
                }
              },
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

  bool _isDataLine(String line) {
    return line.isNotEmpty &&
        !line.startsWith(':') &&
        line.startsWith('data: ');
  }

  Map<String, dynamic>? _parseDataLine(String line) {
    final jsonStr = line.substring(6);
    try {
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (_) {
      return null; // Malformed JSON — skip.
    }
  }
}

class EventsConnectionException implements Exception {
  final int statusCode;
  final String body;

  const EventsConnectionException(this.statusCode, this.body);

  @override
  String toString() => 'EventsConnectionException($statusCode): $body';
}
