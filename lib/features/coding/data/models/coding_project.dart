/// Plano de execução ativo do projeto (`plan` do `GET /coding/projects`).
class CodingPlan {
  final String text;
  final int? maxRuns;
  final int runsUsed;
  final double? maxCostUsd;
  final double costUsed;

  /// Status cru do servidor (exibido como veio).
  final String status;

  const CodingPlan({
    required this.text,
    this.maxRuns,
    this.runsUsed = 0,
    this.maxCostUsd,
    this.costUsed = 0,
    this.status = '',
  });

  factory CodingPlan.fromJson(Map<String, dynamic> json) => CodingPlan(
        text: json['text']?.toString() ?? '',
        maxRuns: json['max_runs'] == null ? null : _int(json['max_runs']),
        runsUsed: _int(json['runs_used']),
        maxCostUsd: _double(json['max_cost_usd']),
        costUsed: _double(json['cost_used']) ?? 0,
        status: json['status']?.toString() ?? '',
      );

  /// Runs que ainda cabem no plano (`null` = sem limite).
  int? get runsLeft =>
      maxRuns == null ? null : (maxRuns! - runsUsed).clamp(0, maxRuns!);

  /// Orçamento que ainda cabe no plano (`null` = sem limite).
  double? get costLeft => maxCostUsd == null
      ? null
      : (maxCostUsd! - costUsed).clamp(0, maxCostUsd!);

  static int _int(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  static double? _double(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse('$value');
  }
}

class CodingProject {
  final int id;
  final String name;
  final String primaryPath;
  final List<String> extraPaths;
  final String permissionMode;
  final List<String> allowRules;
  final List<String> denyRules;
  final String? knowledge;

  /// Branch base do projeto (só leitura no app).
  final String? baseBranch;

  /// `each_run` (aprova cada run) ou `plan` (aprova o plano).
  final String approvalMode;

  /// Plano ativo, quando houver.
  final CodingPlan? plan;

  final String createdAt;
  final String updatedAt;

  const CodingProject({
    required this.id,
    required this.name,
    required this.primaryPath,
    required this.extraPaths,
    required this.permissionMode,
    required this.allowRules,
    required this.denyRules,
    this.knowledge,
    this.baseBranch,
    this.approvalMode = 'each_run',
    this.plan,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CodingProject.fromJson(Map<String, dynamic> json) {
    return CodingProject(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      primaryPath: json['primary_path'] as String? ?? '',
      extraPaths: (json['extra_paths'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      permissionMode: json['permission_mode'] as String? ?? 'default',
      allowRules: (json['allow_rules'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      denyRules: (json['deny_rules'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      knowledge: json['knowledge'] as String?,
      baseBranch: json['base_branch'] as String?,
      approvalMode: json['approval_mode'] as String? ?? 'each_run',
      plan: json['plan'] is Map
          ? CodingPlan.fromJson(Map<String, dynamic>.from(json['plan'] as Map))
          : null,
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'primary_path': primaryPath,
      'extra_paths': extraPaths,
      'permission_mode': permissionMode,
      'allow_rules': allowRules,
      'deny_rules': denyRules,
      if (knowledge != null) 'knowledge': knowledge,
    };
  }

  CodingProject copyWith({
    int? id,
    String? name,
    String? primaryPath,
    List<String>? extraPaths,
    String? permissionMode,
    List<String>? allowRules,
    List<String>? denyRules,
    String? knowledge,
    String? baseBranch,
    String? approvalMode,
    CodingPlan? plan,
    String? createdAt,
    String? updatedAt,
  }) {
    return CodingProject(
      id: id ?? this.id,
      name: name ?? this.name,
      primaryPath: primaryPath ?? this.primaryPath,
      extraPaths: extraPaths ?? this.extraPaths,
      permissionMode: permissionMode ?? this.permissionMode,
      allowRules: allowRules ?? this.allowRules,
      denyRules: denyRules ?? this.denyRules,
      knowledge: knowledge ?? this.knowledge,
      baseBranch: baseBranch ?? this.baseBranch,
      approvalMode: approvalMode ?? this.approvalMode,
      plan: plan ?? this.plan,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

extension CodingProjectPlan on CodingProject {
  /// Troca o plano ativo; `null` limpa (`copyWith` não consegue soltar).
  CodingProject copyWithPlan(CodingPlan? plan) => CodingProject(
        id: id,
        name: name,
        primaryPath: primaryPath,
        extraPaths: extraPaths,
        permissionMode: permissionMode,
        allowRules: allowRules,
        denyRules: denyRules,
        knowledge: knowledge,
        baseBranch: baseBranch,
        approvalMode: approvalMode,
        plan: plan,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
