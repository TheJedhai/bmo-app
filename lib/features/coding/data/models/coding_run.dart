/// Run autônomo de coding (`/api/v1/coding/runs`).
enum CodingRunStatus { queued, running, success, failed, timeout, killed }

CodingRunStatus codingRunStatusFrom(String? raw) => switch (raw) {
  'running' => CodingRunStatus.running,
  'success' => CodingRunStatus.success,
  'failed' => CodingRunStatus.failed,
  'timeout' => CodingRunStatus.timeout,
  'killed' => CodingRunStatus.killed,
  _ => CodingRunStatus.queued,
};

class CodingRun {
  final int id;
  final int projectId;
  final String prompt;
  final CodingRunStatus status;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final String? branch;
  final String? commitSha;
  final List<String> filesChanged;
  final double? costUsd;
  final int? durationMs;
  final DateTime? createdAt;

  /// Motivo da falha, quando o servidor informa (pode vir null — inclusive em
  /// servidor antigo, que não manda esses campos).
  final String? errorCode;
  final String? errorMessage;

  /// Último sinal do run (resumo legível vindo do servidor).
  final String? lastEvent;

  /// Custo real medido pelo servidor. `null` = custo não configurado.
  final double? costUsdComputed;

  /// Uso de tokens (`{input_tokens, output_tokens, cache_*}`), quando houver.
  final Map<String, dynamic>? usage;

  /// Sessão de chat que originou o run (`/coding/:id/chat`).
  final String? sessionId;

  /// Run que originou este (plano/continuação).
  final int? parentRunId;

  /// Plano de execução em que este run está inserido.
  final int? planId;

  /// Quando o run foi juntado na base (`null` = não juntado).
  final DateTime? mergedAt;

  /// JSON recebido do servidor — base para aplicar patches de
  /// `coding.run.updated` sem perder campos.
  final Map<String, dynamic> _raw;

  const CodingRun({
    required this.id,
    required this.projectId,
    required this.prompt,
    required this.status,
    this.startedAt,
    this.endedAt,
    this.branch,
    this.commitSha,
    this.filesChanged = const [],
    this.costUsd,
    this.durationMs,
    this.createdAt,
    this.errorCode,
    this.errorMessage,
    this.lastEvent,
    this.costUsdComputed,
    this.usage,
    this.sessionId,
    this.parentRunId,
    this.planId,
    this.mergedAt,
    Map<String, dynamic> raw = const {},
  }) : _raw = raw;

  /// Run ainda pode ser parado.
  bool get isActive =>
      status == CodingRunStatus.queued || status == CodingRunStatus.running;

  /// Status de falha, onde `error_message` faz sentido mostrar.
  bool get isFailure =>
      status == CodingRunStatus.failed || status == CodingRunStatus.timeout;

  /// Já foi juntado na branch base.
  bool get isMerged => mergedAt != null;

  /// Aplica um `patch` de `coding.run.updated` sobre o último JSON conhecido.
  CodingRun mergePatch(Map<String, dynamic> patch) =>
      CodingRun.fromJson({..._raw, ...patch});

  factory CodingRun.fromJson(Map<String, dynamic> json) => CodingRun(
    id: _int(json['id']),
    projectId: _int(json['project_id']),
    prompt: json['prompt']?.toString() ?? '',
    status: codingRunStatusFrom(json['status']?.toString()),
    startedAt: DateTime.tryParse(json['started_at']?.toString() ?? ''),
    endedAt: DateTime.tryParse(json['ended_at']?.toString() ?? ''),
    branch: json['branch']?.toString(),
    commitSha: json['commit_sha']?.toString(),
    filesChanged:
        (json['files_changed'] as List?)
            ?.map((e) => e is Map ? (e['path'] ?? e).toString() : '$e')
            .toList() ??
        const [],
    costUsd: _double(json['cost_usd']),
    durationMs: json['duration_ms'] == null ? null : _int(json['duration_ms']),
    createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    errorCode: json['error_code']?.toString(),
    errorMessage: json['error_message']?.toString(),
    lastEvent: json['last_event']?.toString(),
    costUsdComputed: _double(json['cost_usd_computed']),
    usage: json['usage'] is Map
        ? Map<String, dynamic>.from(json['usage'] as Map)
        : null,
    sessionId: json['session_id']?.toString(),
    parentRunId: json['parent_run_id'] == null
        ? null
        : _int(json['parent_run_id']),
    planId: json['plan_id'] == null ? null : _int(json['plan_id']),
    mergedAt: DateTime.tryParse(json['merged_at']?.toString() ?? ''),
    raw: json,
  );

  static int _int(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  static double? _double(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value');
  }
}

class CodingRunEvent {
  final int seq;
  final DateTime? ts;
  final String type;
  final Map<String, dynamic> payload;

  const CodingRunEvent({
    required this.seq,
    required this.type,
    this.ts,
    this.payload = const {},
  });

  factory CodingRunEvent.fromJson(Map<String, dynamic> json) => CodingRunEvent(
    seq: CodingRun._int(json['seq']),
    ts: DateTime.tryParse(json['ts']?.toString() ?? ''),
    type: json['type']?.toString() ?? '',
    payload: json['payload'] is Map
        ? Map<String, dynamic>.from(json['payload'] as Map)
        : const {},
  );
}

/// "—" quando não há duração; senão "12s", "3min 05s", "1h 04min".
String formatRunDuration(int? ms) {
  if (ms == null || ms <= 0) return '—';
  final seconds = ms ~/ 1000;
  if (seconds < 60) return '${seconds}s';
  final minutes = seconds ~/ 60;
  if (minutes < 60) {
    return '${minutes}min ${(seconds % 60).toString().padLeft(2, '0')}s';
  }
  return '${minutes ~/ 60}h ${(minutes % 60).toString().padLeft(2, '0')}min';
}

/// "—" quando não há custo; senão "US$ 0.42".
String formatRunCost(double? usd) =>
    usd == null ? '—' : 'US\$ ${usd.toStringAsFixed(2)}';

/// Custo real do run: `cost_usd_computed`; sem ele, o valor não está
/// configurado no servidor.
String formatComputedCost(double? usd) =>
    usd == null ? 'custo não configurado' : formatRunCost(usd);
