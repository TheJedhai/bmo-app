/// Eventos do protocolo de chat v2 (contrato em
/// `bmo-server/docs/chat-v2.md`).
///
/// Todo evento carrega o envelope `session_id`/`turn_id`/`seq`; o `type` do
/// JSON vira uma variante abaixo. Tipo novo entra como [UnknownAgentEvent]
/// (logado e ignorado), nunca quebra o stream.
sealed class AgentEvent {
  final String? sessionId;
  final String? turnId;
  final int? seq;

  const AgentEvent({this.sessionId, this.turnId, this.seq});
}

/// `turn.start`
class TurnStarted extends AgentEvent {
  /// `message` | `approval` | `trigger`.
  final String input;

  const TurnStarted({
    required this.input,
    super.sessionId,
    super.turnId,
    super.seq,
  });
}

/// `text.delta`
class TextDelta extends AgentEvent {
  final String text;

  const TextDelta(this.text, {super.sessionId, super.turnId, super.seq});
}

/// `reasoning.delta`
class ReasoningDelta extends AgentEvent {
  final String text;

  const ReasoningDelta(this.text, {super.sessionId, super.turnId, super.seq});
}

/// `tool.start`
class ToolStarted extends AgentEvent {
  final String callId;
  final String name;
  final String label;

  const ToolStarted({
    required this.callId,
    required this.name,
    required this.label,
    super.sessionId,
    super.turnId,
    super.seq,
  });
}

/// `tool.end`
class ToolEnded extends AgentEvent {
  final String callId;
  final bool ok;
  final String label;

  const ToolEnded({
    required this.callId,
    required this.ok,
    required this.label,
    super.sessionId,
    super.turnId,
    super.seq,
  });
}

/// `rich.block`
class RichBlockReceived extends AgentEvent {
  final String blockId;
  final String richType;
  final Map<String, dynamic> payload;
  final bool mutable;

  /// Resumo falável do bloco (opcional).
  final String? speech;

  const RichBlockReceived({
    required this.blockId,
    required this.richType,
    required this.payload,
    required this.mutable,
    this.speech,
    super.sessionId,
    super.turnId,
    super.seq,
  });
}

/// `approval.request`
class ApprovalRequested extends AgentEvent {
  final String callId;
  final String tool;
  final String label;
  final String summary;

  const ApprovalRequested({
    required this.callId,
    required this.tool,
    required this.label,
    required this.summary,
    super.sessionId,
    super.turnId,
    super.seq,
  });
}

/// Uso de tokens do turno (`turn.end.usage`).
class AgentUsage {
  final int inputTokens;
  final int outputTokens;
  final int cacheHitTokens;

  const AgentUsage({
    required this.inputTokens,
    required this.outputTokens,
    required this.cacheHitTokens,
  });

  static AgentUsage fromJson(Map<String, dynamic> json) => AgentUsage(
        inputTokens: (json['input_tokens'] as num?)?.toInt() ?? 0,
        outputTokens: (json['output_tokens'] as num?)?.toInt() ?? 0,
        cacheHitTokens: (json['cache_hit_tokens'] as num?)?.toInt() ?? 0,
      );
}

/// `turn.end`
class TurnEnded extends AgentEvent {
  /// `completed` | `awaiting_approval` | `cancelled` | `error`.
  final String status;
  final AgentUsage? usage;

  const TurnEnded({
    required this.status,
    this.usage,
    super.sessionId,
    super.turnId,
    super.seq,
  });
}

/// `error` (vem imediatamente antes de um `turn.end` com status `error`).
class AgentErrorEvent extends AgentEvent {
  final String error;
  final String message;

  const AgentErrorEvent(
    this.error,
    this.message, {
    super.sessionId,
    super.turnId,
    super.seq,
  });
}

/// Tipo que este app ainda não conhece (ou evento malformado).
class UnknownAgentEvent extends AgentEvent {
  final String type;
  final Map<String, dynamic> raw;

  const UnknownAgentEvent({
    required this.type,
    required this.raw,
    super.sessionId,
    super.turnId,
    super.seq,
  });
}
