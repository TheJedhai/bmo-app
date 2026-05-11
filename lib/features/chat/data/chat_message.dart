import 'dart:math';

enum ChatRole { user, assistant }

enum ChatMessageStatus { streaming, completed, error, cancelled }

final _idRandom = Random();

String _newMessageId() {
  final micros = DateTime.now().microsecondsSinceEpoch;
  final salt = _idRandom.nextInt(1 << 16).toRadixString(16).padLeft(4, '0');
  return '$micros-$salt';
}

final class ChatMessage {
  final String id;
  final ChatRole role;
  final String text;
  final String? reasoning;
  final ChatMessageStatus status;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.reasoning,
    required this.status,
    required this.createdAt,
  });

  factory ChatMessage.create({
    required ChatRole role,
    required String text,
    String? reasoning,
    required ChatMessageStatus status,
  }) {
    return ChatMessage(
      id: _newMessageId(),
      role: role,
      text: text,
      reasoning: reasoning,
      status: status,
      createdAt: DateTime.now(),
    );
  }

  ChatMessage copyWith({
    String? text,
    String? reasoning,
    ChatMessageStatus? status,
  }) {
    return ChatMessage(
      id: id,
      role: role,
      text: text ?? this.text,
      reasoning: reasoning ?? this.reasoning,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }
}
