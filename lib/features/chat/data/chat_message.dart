import 'dart:math';

enum ChatRole { user, assistant }

enum ChatMessageStatus { streaming, completed, error, cancelled }

/// Estado de uma delegação ao executor externo.
enum DelegationStatus { running, waitingPermission, completed, error }

final _idRandom = Random();

String _newMessageId() {
  final micros = DateTime.now().microsecondsSinceEpoch;
  final salt = _idRandom.nextInt(1 << 16).toRadixString(16).padLeft(4, '0');
  return '$micros-$salt';
}

/// Um evento de delegação (delegate_external_agent) ocorrido durante a
/// resposta do assistant.
final class DelegationEvent {
  final String callId;
  final String? runner;
  final String? cwd;
  final DelegationStatus status;
  final String? report;
  final String? error;

  const DelegationEvent({
    required this.callId,
    this.runner,
    this.cwd,
    required this.status,
    this.report,
    this.error,
  });

  DelegationEvent copyWith({
    String? runner,
    String? cwd,
    DelegationStatus? status,
    String? report,
    String? error,
  }) {
    return DelegationEvent(
      callId: callId,
      runner: runner ?? this.runner,
      cwd: cwd ?? this.cwd,
      status: status ?? this.status,
      report: report ?? this.report,
      error: error ?? this.error,
    );
  }
}

final class ChatMessage {
  final String id;
  final ChatRole role;
  final String text;
  final String? reasoning;
  final ChatMessageStatus status;
  final DateTime createdAt;
  final List<DelegationEvent>? delegations;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.reasoning,
    required this.status,
    required this.createdAt,
    this.delegations,
  });

  factory ChatMessage.create({
    required ChatRole role,
    required String text,
    String? reasoning,
    required ChatMessageStatus status,
    List<DelegationEvent>? delegations,
  }) {
    return ChatMessage(
      id: _newMessageId(),
      role: role,
      text: text,
      reasoning: reasoning,
      status: status,
      createdAt: DateTime.now(),
      delegations: delegations,
    );
  }

  ChatMessage copyWith({
    String? text,
    String? reasoning,
    ChatMessageStatus? status,
    List<DelegationEvent>? delegations,
  }) {
    return ChatMessage(
      id: id,
      role: role,
      text: text ?? this.text,
      reasoning: reasoning ?? this.reasoning,
      status: status ?? this.status,
      createdAt: createdAt,
      delegations: delegations ?? this.delegations,
    );
  }
}
