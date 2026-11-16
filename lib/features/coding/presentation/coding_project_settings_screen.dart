import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/identity/identity_state.dart';
import '../../../core/theme/bmo_theme.dart';
import '../data/coding_client.dart';
import '../data/coding_providers.dart';
import '../data/models/coding_project.dart';
import 'widgets/permission_modes.dart';

/// Configurações do projeto — `/coding/:projectId/settings`.
///
/// Edita `permission_mode`, as regras allow/deny e o `approval_mode`.
/// `base_branch` é só leitura (o servidor decide). O plano ativo aparece com
/// o consumo (runs e US$); não há botão de cancelar porque o servidor ainda
/// não expõe rota para isso.
class CodingProjectSettingsScreen extends ConsumerStatefulWidget {
  final int projectId;

  const CodingProjectSettingsScreen({super.key, required this.projectId});

  @override
  ConsumerState<CodingProjectSettingsScreen> createState() =>
      _CodingProjectSettingsScreenState();
}

class _CodingProjectSettingsScreenState
    extends ConsumerState<CodingProjectSettingsScreen> {
  final _allowController = TextEditingController();
  final _denyController = TextEditingController();

  String? _permissionMode;
  String? _approvalMode;
  List<String> _allowRules = const [];
  List<String> _denyRules = const [];
  bool _saving = false;
  String? _error;

  /// Hidrata uma vez: rebuild por regra adicionada não pode voltar ao valor
  /// original do projeto.
  bool _hydrated = false;

  @override
  void dispose() {
    _allowController.dispose();
    _denyController.dispose();
    super.dispose();
  }

  CodingProject? _project(List<CodingProject>? projects) {
    for (final project in projects ?? const <CodingProject>[]) {
      if (project.id == widget.projectId) return project;
    }
    return null;
  }

  void _hydrate(CodingProject project) {
    if (_hydrated) return;
    _hydrated = true;
    _permissionMode = project.permissionMode;
    _approvalMode = project.approvalMode;
    _allowRules = project.allowRules;
    _denyRules = project.denyRules;
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(projectsProvider.notifier).updateProject(
        widget.projectId,
        {
          'permission_mode': _permissionMode,
          'approval_mode': _approvalMode,
          'allow_rules': _allowRules,
          'deny_rules': _denyRules,
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('configurações salvas')),
      );
    } catch (e) {
      if (mounted) setState(() => _error = 'falha ao salvar: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addRule({required bool allow}) {
    final controller = allow ? _allowController : _denyController;
    final value = controller.text.trim();
    if (value.isEmpty) return;
    setState(() {
      if (allow) {
        _allowRules = [..._allowRules, value];
        _allowController.clear();
      } else {
        _denyRules = [..._denyRules, value];
        _denyController.clear();
      }
    });
  }

  Future<void> _cancelPlan() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BmoColors.screenBgElevated,
        title: const Text('Cancelar plano?'),
        content: const Text(
          'O plano ativo é encerrado e os runs que faltam não rodam.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: BmoColors.accentRed),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cancelar plano'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(codingClientProvider).cancelPlan(widget.projectId);
      if (!mounted) return;
      // Limpa já; o `coding.plan.updated` do servidor confirma.
      ref.read(projectsProvider.notifier).applyPlan(widget.projectId, null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('plano cancelado')),
      );
    } catch (e) {
      if (!mounted) return;
      // 409 = sem plano ativo: não é falha do usuário.
      final message = e is CodingApiException && e.statusCode == 409
          ? 'não há plano ativo'
          : 'falha ao cancelar o plano: $e';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _removeRule({required bool allow, required int index}) {
    setState(() {
      final list = allow ? _allowRules : _denyRules;
      final next = [...list]..removeAt(index);
      if (allow) {
        _allowRules = next;
      } else {
        _denyRules = next;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final features = ref.watch(enabledFeaturesProvider);
    if (!features.contains('coding')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) GoRouter.of(context).go('/');
      });
      return const SizedBox.shrink();
    }

    final projectsAsync = ref.watch(projectsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          _Header(projectId: widget.projectId),
          Expanded(
            child: projectsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: BmoColors.accentGreen,
                ),
              ),
              error: (error, _) => Center(child: Text('falha: $error')),
              data: (projects) {
                final project = _project(projects);
                if (project == null) {
                  return const Center(child: Text('projeto não encontrado'));
                }
                _hydrate(project);
                return _body(context, project);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, CodingProject project) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      children: [
        _Section(
          title: 'MODO DE PERMISSÃO',
          child: PermissionModeSelector(
            value: _permissionMode ?? project.permissionMode,
            onChanged: (value) => setState(() => _permissionMode = value),
          ),
        ),
        _Section(
          title: 'APROVAÇÃO',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _approvalMode ?? project.approvalMode,
                isExpanded: true,
                dropdownColor: BmoColors.screenBgElevated,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: BmoColors.textPrimary),
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: BmoColors.screenBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'each_run',
                    child: Text('Aprovar cada run'),
                  ),
                  DropdownMenuItem(
                    value: 'plan',
                    child: Text('Aprovar o plano'),
                  ),
                ],
                onChanged: (next) {
                  if (next != null) setState(() => _approvalMode = next);
                },
              ),
              const SizedBox(height: 4),
              Text(
                _approvalMode == 'plan'
                    ? 'O BMO propõe um plano e espera aprovação uma vez.'
                    : 'Cada execução pede aprovação antes de rodar.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: BmoColors.textMuted),
              ),
            ],
          ),
        ),
        _Section(
          title: 'REGRAS ALLOW',
          child: _RuleList(
            rules: _allowRules,
            controller: _allowController,
            hint: 'ex.: ext: .py',
            onAdd: () => _addRule(allow: true),
            onRemove: (index) => _removeRule(allow: true, index: index),
          ),
        ),
        _Section(
          title: 'REGRAS DENY',
          child: _RuleList(
            rules: _denyRules,
            controller: _denyController,
            hint: 'ex.: path: secrets/',
            onAdd: () => _addRule(allow: false),
            onRemove: (index) => _removeRule(allow: false, index: index),
          ),
        ),
        _Section(
          title: 'BRANCH BASE',
          child: Text(
            project.baseBranch ?? 'não informada',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: BmoColors.textSecondary),
          ),
        ),
        _Section(
          title: 'PLANO ATIVO',
          child: _PlanCard(plan: project.plan, onCancel: _cancelPlan),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: BmoColors.accentRed),
          ),
        ],
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: BmoColors.accentGreen,
              foregroundColor: const Color(0xFF0F1115),
            ),
            child: Text(_saving ? 'salvando...' : 'Salvar'),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final int projectId;

  const _Header({required this.projectId});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              if (GoRouter.of(context).canPop()) {
                GoRouter.of(context).pop();
              } else {
                GoRouter.of(context).go('/coding/$projectId');
              }
            },
            icon: const Icon(Icons.arrow_back, size: 20),
            color: BmoColors.textSecondary,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          const SizedBox(width: 8),
          Text(
            'CONFIG',
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 14,
              color: BmoColors.accentGreen,
              shadows: [
                Shadow(
                  color: BmoColors.accentGreen.withValues(alpha: 0.3),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 10,
              color: BmoColors.accentGreen.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _RuleList extends StatelessWidget {
  final List<String> rules;
  final TextEditingController controller;
  final String hint;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  const _RuleList({
    required this.rules,
    required this.controller,
    required this.hint,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (rules.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              'nenhuma regra',
              style:
                  theme.textTheme.bodySmall?.copyWith(color: BmoColors.textMuted),
            ),
          ),
        for (var i = 0; i < rules.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: BmoColors.screenBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    rules[i],
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: BmoColors.textPrimary),
                  ),
                ),
                IconButton(
                  tooltip: 'remover',
                  iconSize: 16,
                  color: BmoColors.textMuted,
                  onPressed: () => onRemove(i),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                onSubmitted: (_) => onAdd(),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: BmoColors.textPrimary),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: hint,
                  hintStyle: theme.textTheme.bodySmall
                      ?.copyWith(color: BmoColors.textMuted),
                  filled: true,
                  fillColor: BmoColors.screenBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(onPressed: onAdd, child: const Text('adicionar')),
          ],
        ),
      ],
    );
  }
}

/// Rótulo e cor de um status de plano. Desconhecido aparece cru.
({String label, Color color}) planStatusLook(String status) => switch (status) {
      'active' => (label: 'ativo', color: BmoColors.accentGreen),
      'exhausted' => (
          label: 'orçamento esgotado',
          color: BmoColors.accentRed,
        ),
      'cancelled' => (label: 'cancelado', color: BmoColors.textMuted),
      _ => (label: status, color: BmoColors.textSecondary),
    };

class _PlanCard extends StatelessWidget {
  final CodingPlan? plan;
  final VoidCallback? onCancel;

  const _PlanCard({required this.plan, this.onCancel});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plan = this.plan;
    if (plan == null) {
      return Text(
        'sem plano ativo',
        style: theme.textTheme.bodySmall?.copyWith(color: BmoColors.textMuted),
      );
    }

    final statusLook =
        plan.status.isEmpty ? null : planStatusLook(plan.status);

    String budget(int used, int? max) =>
        max == null ? '$used (sem limite)' : '$used / $max';
    String money(double used, double? max) =>
        max == null ? formatMoney(used) : '${formatMoney(used)} / ${formatMoney(max)}';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BmoColors.screenBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: BmoColors.accentYellow.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (plan.text.isNotEmpty)
            Text(
              plan.text,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: BmoColors.textPrimary),
            ),
          const SizedBox(height: 8),
          Text(
            'runs: ${budget(plan.runsUsed, plan.maxRuns)}',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: BmoColors.textSecondary),
          ),
          Text(
            'custo: ${money(plan.costUsed, plan.maxCostUsd)}',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: BmoColors.textSecondary),
          ),
          if (statusLook != null)
            Text(
              'status: ${statusLook.label}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: statusLook.color),
            ),
          if (onCancel != null) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: onCancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: BmoColors.accentRed,
                side: BorderSide(
                  color: BmoColors.accentRed.withValues(alpha: 0.6),
                ),
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('Cancelar plano'),
            ),
          ],
        ],
      ),
    );
  }
}

/// "US$ 1.25" — custo do plano em dólar com 2 casas.
String formatMoney(double usd) => 'US\$ ${usd.toStringAsFixed(2)}';
