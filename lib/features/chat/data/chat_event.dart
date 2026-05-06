/// Eventos do protocolo SSE do bmo-server (compatível QwenPaw).
///
/// O parser inspeciona campos `object`, `status`, `delta`, `type`, `error`
/// do JSON e devolve a variante apropriada. Casos não reconhecidos viram
/// [UnknownEvent] (logados upstream).
sealed class ChatEvent {
  const ChatEvent();

  factory ChatEvent.fromJson(Map<String, dynamic> json) {
    final error = json['error'];
    if (error != null) {
      return StreamError(
        error: error.toString(),
        details: json['details'] is Map<String, dynamic>
            ? json['details'] as Map<String, dynamic>
            : null,
      );
    }

    final object = json['object'] as String?;
    final status = json['status'] as String?;

    if (object == 'response') {
      switch (status) {
        case 'created':
          return ResponseCreated(
            responseId: json['id'] as String? ?? '',
            sessionId: json['session_id'] as String? ?? '',
          );
        case 'in_progress':
          return const ResponseInProgress();
        case 'completed':
          final usage = json['usage'];
          return ResponseCompleted(
            responseId: json['id'] as String? ?? '',
            sessionId: json['session_id'] as String? ?? '',
            usage: usage is Map<String, dynamic> ? usage : null,
          );
      }
    }

    if (object == 'message') {
      if (status == 'in_progress') {
        return MessageStarted(
          messageId: json['id'] as String? ?? '',
          messageType: json['type'] as String? ?? '',
          role: json['role'] as String? ?? '',
        );
      }
      if (status == 'completed') {
        final content = json['content'];
        final buffer = StringBuffer();
        if (content is List) {
          for (final item in content) {
            if (item is Map && item['type'] == 'text') {
              final text = item['text'];
              if (text is String) buffer.write(text);
            }
          }
        }
        return MessageCompleted(
          messageId: json['id'] as String? ?? '',
          messageType: json['type'] as String? ?? '',
          fullText: buffer.toString(),
        );
      }
    }

    if (object == 'content') {
      final type = json['type'] as String?;
      final delta = json['delta'] == true;
      if (type == 'text' && delta) {
        return TextDelta(
          messageId: json['msg_id'] as String? ?? '',
          text: json['text'] as String? ?? '',
          index: (json['index'] as num?)?.toInt() ?? 0,
        );
      }
      // status completed, delta=false ou null → ignoramos pra não duplicar texto
    }

    return UnknownEvent(rawJson: json);
  }
}

final class ResponseCreated extends ChatEvent {
  final String responseId;
  final String sessionId;
  const ResponseCreated({required this.responseId, required this.sessionId});
}

final class ResponseInProgress extends ChatEvent {
  const ResponseInProgress();
}

final class ResponseCompleted extends ChatEvent {
  final String responseId;
  final String sessionId;
  final Map<String, dynamic>? usage;
  const ResponseCompleted({
    required this.responseId,
    required this.sessionId,
    this.usage,
  });
}

final class MessageStarted extends ChatEvent {
  final String messageId;
  final String messageType; // "reasoning" ou "message"
  final String role;
  const MessageStarted({
    required this.messageId,
    required this.messageType,
    required this.role,
  });
}

final class TextDelta extends ChatEvent {
  final String messageId;
  final String text;
  final int index;
  const TextDelta({
    required this.messageId,
    required this.text,
    required this.index,
  });
}

final class MessageCompleted extends ChatEvent {
  final String messageId;
  final String messageType;
  final String fullText;
  const MessageCompleted({
    required this.messageId,
    required this.messageType,
    required this.fullText,
  });
}

final class StreamError extends ChatEvent {
  final String error;
  final Map<String, dynamic>? details;
  const StreamError({required this.error, this.details});
}

final class UnknownEvent extends ChatEvent {
  final Map<String, dynamic> rawJson;
  const UnknownEvent({required this.rawJson});
}
