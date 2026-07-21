import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class EventsClient {
  final http.Client _client;
  final String _baseUrl;

  EventsClient({required http.Client client, required String baseUrl})
      : _client = client,
        _baseUrl = baseUrl;

  Stream<Map<String, dynamic>> connect() async* {
    final request = http.Request('GET', Uri.parse('$_baseUrl/api/v1/stream'));
    request.headers['Accept'] = 'text/event-stream';

    final streamedResponse = await _client.send(request);
    if (streamedResponse.statusCode != 200) {
      final body = await streamedResponse.stream.bytesToString();
      throw EventsConnectionException(streamedResponse.statusCode, body);
    }

    yield* streamedResponse.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .where(_isDataLine)
        .map(_parseDataLine)
        .where((event) => event != null)
        .cast<Map<String, dynamic>>();
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
