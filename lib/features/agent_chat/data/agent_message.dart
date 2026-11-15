import 'dart:developer' as developer;

/// Mensagem do chat v2: partes ordenadas, espelhando o formato de exibição do
/// contrato (`GET /api/v2/sessions/{id}/messages`).
///
/// O histórico (REST) e o streaming ao vivo produzem o mesmo modelo: o
/// notifier só vai anexando/substituindo partes.
enum AgentRole { user, assistant }

sealed class AgentPart {
  const AgentPart();
}

class AgentTextPart extends AgentPart {
  final String text;

  const AgentTextPart(this.text);
}

class AgentReasoningPart extends AgentPart {
  final String text;

  const AgentReasoningPart(this.text);
}

enum AgentToolStatus { running, awaiting, ok, failed, denied }

class AgentToolPart extends AgentPart {
  final String callId;
  final String name;
  final String label;
  final AgentToolStatus status;

  const AgentToolPart({
    required this.callId,
    required this.name,
    required this.label,
    required this.status,
  });

  AgentToolPart copyWith({AgentToolStatus? status}) => AgentToolPart(
        callId: callId,
        name: name,
        label: label,
        status: status ?? this.status,
      );
}

class AgentRichPart extends AgentPart {
  final String blockId;
  final String richType;
  final Map<String, dynamic> payload;
  final bool mutable;

  const AgentRichPart({
    required this.blockId,
    required this.richType,
    required this.payload,
    required this.mutable,
  });
}

enum AgentApprovalDecision { pending, approved, denied }

class AgentApprovalPart extends AgentPart {
  final String callId;
  final String tool;
  final String label;
  final String summary;
  final AgentApprovalDecision decision;

  /// Negada porque o usuário mandou outra mensagem em vez de decidir.
  final bool ignored;

  const AgentApprovalPart({
    required this.callId,
    required this.tool,
    required this.label,
    required this.summary,
    required this.decision,
    this.ignored = false,
  });

  AgentApprovalPart copyWith({
    AgentApprovalDecision? decision,
    bool? ignored,
  }) =>
      AgentApprovalPart(
        callId: callId,
        tool: tool,
        label: label,
        summary: summary,
        decision: decision ?? this.decision,
        ignored: ignored ?? this.ignored,
      );
}

class AgentMessage {
  final String id;
  final AgentRole role;
  final DateTime? createdAt;
  final List<AgentPart> parts;

  const AgentMessage({
    required this.id,
    required this.role,
    required this.parts,
    this.createdAt,
  });

  bool get isAssistant => role == AgentRole.assistant;

  String get plainText => parts
      .whereType<AgentTextPart>()
      .map((part) => part.text)
      .join();

  String get plainReasoning => parts
      .whereType<AgentReasoningPart>()
      .map((part) => part.text)
      .join();

  AgentMessage copyWith({List<AgentPart>? parts, DateTime? createdAt}) =>
      AgentMessage(
        id: id,
        role: role,
        parts: parts ?? this.parts,
        createdAt: createdAt ?? this.createdAt,
      );

  static AgentMessage streamingAssistant(String id) => AgentMessage(
        id: id,
        role: AgentRole.assistant,
        parts: const [],
      );

  /// Lê uma mensagem do formato de exibição do contrato.
  static AgentMessage fromJson(Map<String, dynamic> json) {
    final role = json['role'] == 'user' ? AgentRole.user : AgentRole.assistant;
    final rawParts = json['parts'];
    final parts = <AgentPart>[];
    if (rawParts is List) {
      for (final raw in rawParts) {
        if (raw is! Map) continue;
        final part = parseAgentPart(Map<String, dynamic>.from(raw));
        if (part != null) parts.add(part);
      }
    }
    _resolveApprovalTools(parts);
    return AgentMessage(
      id: json['id']?.toString() ?? '',
      role: role,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      parts: parts,
    );
  }
}

/// O histórico só traz `ok` no tool; a `decision` da aprovação do mesmo
/// `call_id` completa o estado que o stream ao vivo entrega.
void _resolveApprovalTools(List<AgentPart> parts) {
  final decisions = <String, AgentApprovalDecision>{
    for (final part in parts)
      if (part is AgentApprovalPart) part.callId: part.decision,
  };
  if (decisions.isEmpty) return;
  for (var i = 0; i < parts.length; i++) {
    final part = parts[i];
    if (part is! AgentToolPart) continue;
    final status = switch (decisions[part.callId]) {
      AgentApprovalDecision.pending => AgentToolStatus.awaiting,
      AgentApprovalDecision.denied => AgentToolStatus.denied,
      AgentApprovalDecision.approved || null => part.status,
    };
    parts[i] = part.copyWith(status: status);
  }
}

/// Parte desconhecida é descartada com log (o contrato pode crescer).
AgentPart? parseAgentPart(Map<String, dynamic> json) {
  switch (json['type']) {
    case 'text':
      final text = json['text'];
      return text is String ? AgentTextPart(text) : null;
    case 'reasoning':
      final text = json['text'];
      return text is String ? AgentReasoningPart(text) : null;
    case 'tool':
      final callId = json['call_id'];
      final name = json['name'];
      if (callId is! String || name is! String) return null;
      return AgentToolPart(
        callId: callId,
        name: name,
        label: json['label'] is String ? json['label'] as String : name,
        status: json['ok'] == true ? AgentToolStatus.ok : AgentToolStatus.failed,
      );
    case 'rich':
      final blockId = json['block_id'];
      final richType = json['rich_type'];
      final payload = json['payload'];
      if (blockId is! String || richType is! String) return null;
      return AgentRichPart(
        blockId: blockId,
        richType: richType,
        payload: payload is Map
            ? Map<String, dynamic>.from(payload)
            : const <String, dynamic>{},
        mutable: json['mutable'] == true,
      );
    case 'approval':
      final callId = json['call_id'];
      final tool = json['tool'];
      if (callId is! String || tool is! String) return null;
      return AgentApprovalPart(
        callId: callId,
        tool: tool,
        label: json['label'] is String ? json['label'] as String : tool,
        summary: json['summary'] is String ? json['summary'] as String : '',
        decision: switch (json['decision']) {
          'approved' => AgentApprovalDecision.approved,
          'denied' => AgentApprovalDecision.denied,
          _ => AgentApprovalDecision.pending,
        },
      );
    default:
      developer.log(
        'parte v2 desconhecida: ${json['type']}',
        name: 'agent_message',
        level: 900,
      );
      return null;
  }
}
