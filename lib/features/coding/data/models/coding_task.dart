/// Tarefa de coding (`/api/v1/coding/tasks`): objetivo + passos que o
/// operário executa, com as tentativas (runs) de cada passo.
///
/// O objeto do REST (`CodingTaskRead`) e o patch de `coding.task.*` têm o
/// mesmo shape; os passos (`steps`) só vêm no REST.
enum CodingTaskStatus {
  draft,
  awaitingApproval,
  running,
  readyToJoin,
  joined,
  blocked,
  cancelled,
}

/// Status vêm do servidor em pt-BR (contrato fechado).
CodingTaskStatus codingTaskStatusFrom(String? raw) => switch (raw) {
  'aguardando_aprovacao' => CodingTaskStatus.awaitingApproval,
  'executando' => CodingTaskStatus.running,
  'pronta_para_juntar' => CodingTaskStatus.readyToJoin,
  'juntada' => CodingTaskStatus.joined,
  'bloqueada' => CodingTaskStatus.blocked,
  'cancelada' => CodingTaskStatus.cancelled,
  _ => CodingTaskStatus.draft,
};

extension CodingTaskStatusWire on CodingTaskStatus {
  /// Valor que o servidor usa no campo `status`.
  String get wire => switch (this) {
    CodingTaskStatus.draft => 'rascunho',
    CodingTaskStatus.awaitingApproval => 'aguardando_aprovacao',
    CodingTaskStatus.running => 'executando',
    CodingTaskStatus.readyToJoin => 'pronta_para_juntar',
    CodingTaskStatus.joined => 'juntada',
    CodingTaskStatus.blocked => 'bloqueada',
    CodingTaskStatus.cancelled => 'cancelada',
  };
}

enum CodingStepStatus { pending, running, reviewing, done, failed }

CodingStepStatus codingStepStatusFrom(String? raw) => switch (raw) {
  'executando' => CodingStepStatus.running,
  'revisando' => CodingStepStatus.reviewing,
  'feito' => CodingStepStatus.done,
  'falhou' => CodingStepStatus.failed,
  _ => CodingStepStatus.pending,
};

class CodingTaskStep {
  final int stepId;
  final int seq;
  final String title;
  final String prompt;
  final CodingStepStatus status;
  final int attempts;
  final int maxAttempts;
  final String? commitSha;

  /// Veredito do revisor: `ok` | `refazer` | `parar` (null enquanto não há).
  final String? verdict;
  final String? note;
  final String? lastError;
  final double? costUsd;
  final int? durationMs;

  const CodingTaskStep({
    required this.stepId,
    required this.seq,
    required this.title,
    required this.prompt,
    required this.status,
    this.attempts = 0,
    this.maxAttempts = 0,
    this.commitSha,
    this.verdict,
    this.note,
    this.lastError,
    this.costUsd,
    this.durationMs,
  });

  factory CodingTaskStep.fromJson(Map<String, dynamic> json) {
    final verdict = json['verdict'] is Map
        ? Map<String, dynamic>.from(json['verdict'] as Map)
        : null;
    return CodingTaskStep(
      stepId: _asInt(json['step_id']),
      seq: _asInt(json['seq']),
      title: json['title']?.toString() ?? '',
      prompt: json['prompt']?.toString() ?? '',
      status: codingStepStatusFrom(json['status']?.toString()),
      attempts: _asInt(json['attempts']),
      maxAttempts: _asInt(json['max_attempts']),
      commitSha: json['commit_sha']?.toString(),
      verdict: verdict?['verdict']?.toString(),
      note: verdict?['nota']?.toString(),
      lastError: json['last_error']?.toString(),
      costUsd: _asDouble(json['cost_usd']),
      durationMs: json['duration_ms'] == null
          ? null
          : _asInt(json['duration_ms']),
    );
  }
}

class CodingTask {
  final int taskId;
  final int projectId;
  final String? sessionId;
  final CodingTaskStatus status;
  final String objective;
  final int currentStep;
  final int stepsTotal;
  final int stepsDone;
  final double? costUsd;
  final int? durationMs;
  final String? lastEvent;
  final String? errorCode;
  final String? errorMessage;
  final String? branch;
  final String? baseBranch;
  final String? model;
  final String? effort;
  final DateTime? joinedAt;
  final DateTime? approvedAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final DateTime? createdAt;

  /// Servidor liberou o "Juntar" (tarefa pronta para juntar e checkout limpo).
  final bool canJoin;

  /// Passos com prompt, tentativas, veredito e commit. Só no REST.
  final List<CodingTaskStep> steps;

  const CodingTask({
    required this.taskId,
    required this.projectId,
    this.sessionId,
    required this.status,
    required this.objective,
    this.currentStep = 0,
    this.stepsTotal = 0,
    this.stepsDone = 0,
    this.costUsd,
    this.durationMs,
    this.lastEvent,
    this.errorCode,
    this.errorMessage,
    this.branch,
    this.baseBranch,
    this.model,
    this.effort,
    this.joinedAt,
    this.approvedAt,
    this.startedAt,
    this.endedAt,
    this.createdAt,
    this.canJoin = false,
    this.steps = const [],
  });

  /// Pode ser cancelada (executando ou esperando aprovação).
  bool get canCancel =>
      status == CodingTaskStatus.running ||
      status == CodingTaskStatus.awaitingApproval;

  /// Bloqueada: o "Retomar" devolve tentativas ao passo que falhou.
  bool get canResume => status == CodingTaskStatus.blocked;

  factory CodingTask.fromJson(Map<String, dynamic> json) => CodingTask(
    taskId: _int(json['task_id'] ?? json['id']),
    projectId: _int(json['project_id']),
    sessionId: json['session_id']?.toString(),
    status: codingTaskStatusFrom(json['status']?.toString()),
    objective: json['objective']?.toString() ?? '',
    currentStep: _int(json['current_step']),
    stepsTotal: _int(json['steps_total']),
    stepsDone: _int(json['steps_done']),
    costUsd: _double(json['cost_usd']),
    durationMs: json['duration_ms'] == null ? null : _int(json['duration_ms']),
    lastEvent: json['last_event']?.toString(),
    errorCode: json['error_code']?.toString(),
    errorMessage: json['error_message']?.toString(),
    branch: json['branch']?.toString(),
    baseBranch: json['base_branch']?.toString(),
    model: json['model']?.toString(),
    effort: json['effort']?.toString(),
    joinedAt: DateTime.tryParse(json['joined_at']?.toString() ?? ''),
    approvedAt: DateTime.tryParse(json['approved_at']?.toString() ?? ''),
    startedAt: DateTime.tryParse(json['started_at']?.toString() ?? ''),
    endedAt: DateTime.tryParse(json['ended_at']?.toString() ?? ''),
    createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    canJoin: json['can_join'] == true,
    steps:
        (json['steps'] as List?)
            ?.whereType<Map>()
            .map((e) => CodingTaskStep.fromJson(Map<String, dynamic>.from(e)))
            .toList() ??
        const [],
  );

  static int _int(dynamic value) => _asInt(value);

  static double? _double(dynamic value) => _asDouble(value);
}

int _asInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}

double? _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value');
}
