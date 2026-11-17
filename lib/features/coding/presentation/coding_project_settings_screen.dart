import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/identity/identity_state.dart';
import '../../../core/theme/bmo_theme.dart';
import '../data/coding_providers.dart';
import '../data/models/coding_project.dart';
import 'widgets/permission_modes.dart';

/// Configurações do projeto — `/coding/:projectId/settings`.
///
/// Edita `permission_mode` e as regras allow/deny. `base_branch` é só leitura
/// (o servidor decide).
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
          title: 'REGRAS ALLOW',
          child: _RuleList(
            rules: _allowRules,
            controller: _allowController,
            hint: 'Bash(npm test:*) ou Edit',
            help: 'Ferramentas desta versão: Bash, Read e Edit '
                '(Write não existe).',
            onAdd: () => _addRule(allow: true),
            onRemove: (index) => _removeRule(allow: true, index: index),
          ),
        ),
        _Section(
          title: 'REGRAS DENY',
          child: _RuleList(
            rules: _denyRules,
            controller: _denyController,
            hint: 'Read(./secrets/**)',
            help: 'Deny bloqueia sem aviso, mesmo em bypassPermissions.',
            onAdd: () => _addRule(allow: false),
            onRemove: (index) => _removeRule(allow: false, index: index),
          ),
        ),
        _Section(
          title: 'BRANCH BASE',
          child: Text(
            project.baseBranch ??
                'definida no próximo run (branch atual do repositório)',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: BmoColors.textSecondary),
          ),
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

class _RuleList extends StatefulWidget {
  final List<String> rules;
  final TextEditingController controller;
  final String hint;
  final String help;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  const _RuleList({
    required this.rules,
    required this.controller,
    required this.hint,
    required this.help,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  State<_RuleList> createState() => _RuleListState();
}

class _RuleListState extends State<_RuleList> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_syncText);
    _syncText();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncText);
    super.dispose();
  }

  /// Botão "adicionar" só habilita com algo digitado — campo vazio é no-op.
  void _syncText() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (hasText == _hasText) return;
    setState(() => _hasText = hasText);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.rules.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              'nenhuma regra',
              style:
                  theme.textTheme.bodySmall?.copyWith(color: BmoColors.textMuted),
            ),
          ),
        for (var i = 0; i < widget.rules.length; i++)
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
                    widget.rules[i],
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: BmoColors.textPrimary),
                  ),
                ),
                IconButton(
                  tooltip: 'remover',
                  iconSize: 16,
                  color: BmoColors.textMuted,
                  onPressed: () => widget.onRemove(i),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: widget.controller,
                // Enter no campo também adiciona.
                onSubmitted: (_) {
                  if (_hasText) widget.onAdd();
                },
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: BmoColors.textPrimary),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: widget.hint,
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
            TextButton(
              onPressed: _hasText ? widget.onAdd : null,
              child: const Text('adicionar'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          widget.help,
          style: theme.textTheme.bodySmall?.copyWith(
            color: BmoColors.textMuted,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
