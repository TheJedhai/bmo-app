import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/bmo_theme.dart';
import '../data/agent_session.dart';
import '../providers/agent_chat_providers.dart';

/// Sidebar de sessões do chat v2: nova, renomear, apagar e buscar.
///
/// [projectId] escolhe a família de sessões: `null` = chat principal,
/// `N` = conversas daquele projeto.
class AgentSessionList extends ConsumerStatefulWidget {
  final VoidCallback? onItemTap;
  final int? projectId;

  const AgentSessionList({super.key, this.onItemTap, this.projectId});

  @override
  ConsumerState<AgentSessionList> createState() => _AgentSessionListState();
}

class _AgentSessionListState extends ConsumerState<AgentSessionList> {
  final _searchController = TextEditingController();
  String _query = '';

  /// Quantos dias ficam sempre visíveis; o resto entra em "Mais dias (N)".
  static const _kCollapsedDays = 3;

  bool _daysExpanded = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Conversa nova: sem sessão ainda. O servidor cria a sessão no primeiro
  /// envio (que vai com `session_id: null`) e a lista é atualizada no
  /// `turn.start`.
  void _create() {
    ref.read(selectedAgentSessionProvider(widget.projectId).notifier).select(null);
    widget.onItemTap?.call();
  }

  Future<void> _rename(AgentSession session) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _RenameSessionDialog(currentName: session.title),
    );
    if (name == null || name.trim().isEmpty) return;
    try {
      await ref
        .read(agentSessionsProvider(widget.projectId).notifier)
        .rename(session.id, name.trim());
    } catch (e) {
      _snack('falha ao renomear: $e');
    }
  }

  Future<void> _delete(AgentSession session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BmoColors.screenBgElevated,
        title: const Text('Apagar conversa?'),
        content: Text(
          session.title,
          style: const TextStyle(color: BmoColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: BmoColors.accentRed,
              foregroundColor: const Color(0xFF0F1115),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
        .read(agentSessionsProvider(widget.projectId).notifier)
        .delete(session.id);
      if (ref.read(selectedAgentSessionProvider(widget.projectId)) ==
          session.id) {
        ref.read(selectedAgentSessionProvider(widget.projectId).notifier).select(null);
      }
    } catch (e) {
      _snack('falha ao apagar: $e');
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  List<AgentSession> _filter(List<AgentSession> sessions) => _query.isEmpty
      ? sessions
      : sessions
          .where((s) => s.title.toLowerCase().contains(_query.toLowerCase()))
          .toList();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sessionsAsync =
        ref.watch(agentSessionsProvider(widget.projectId));
    final selected = ref.watch(selectedAgentSessionProvider(widget.projectId));
    // Seção "Dias" só no chat principal.
    final dailyAsync = widget.projectId == null
        ? ref.watch(dailyAgentSessionsProvider)
        : null;

    return Container(
      color: BmoColors.screenBg,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _create,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nova'),
                style: FilledButton.styleFrom(
                  backgroundColor: BmoColors.accentGreen,
                  foregroundColor: const Color(0xFF0F1115),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value.trim()),
              style: theme.textTheme.bodySmall?.copyWith(
                color: BmoColors.textPrimary,
              ),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'buscar',
                hintStyle: theme.textTheme.bodySmall?.copyWith(
                  color: BmoColors.textMuted,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  size: 16,
                  color: BmoColors.textMuted,
                ),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(
                          Icons.clear,
                          size: 16,
                          color: BmoColors.textMuted,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
                filled: true,
                fillColor: BmoColors.screenBgElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: sessionsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: BmoColors.accentGreen),
              ),
              error: (error, _) => _SessionsError(
                error: error,
                onRetry: () => ref.invalidate(agentSessionsProvider(widget.projectId)),
              ),
              data: (sessions) {
                final daily = dailyAsync?.valueOrNull ?? const <AgentSession>[];
                final filtered = _filter(sessions);
                final filteredDaily = _filter(daily);
                if (sessions.isEmpty && daily.isEmpty) {
                  return const _SessionsEmpty(
                    text: 'nenhuma conversa ainda',
                  );
                }
                if (filtered.isEmpty && filteredDaily.isEmpty) {
                  return const _SessionsEmpty(text: 'nada encontrado');
                }
                void select(String? id) {
                  ref
                      .read(selectedAgentSessionProvider(widget.projectId)
                          .notifier)
                      .select(id);
                  widget.onItemTap?.call();
                }

                // Dias: os 3 mais recentes; o resto recolhe. A sessão
                // selecionada fica visível mesmo sendo antiga.
                var visibleDaily = filteredDaily;
                var hiddenDays = 0;
                if (_query.isEmpty &&
                    filteredDaily.length > _kCollapsedDays) {
                  final rest = filteredDaily.skip(_kCollapsedDays).toList();
                  AgentSession? selectedDaily;
                  for (final session in rest) {
                    if (session.id == selected) selectedDaily = session;
                  }
                  hiddenDays = rest.length - (selectedDaily == null ? 0 : 1);
                  if (!_daysExpanded) {
                    visibleDaily = [
                      ...filteredDaily.take(_kCollapsedDays),
                      if (selectedDaily != null) selectedDaily,
                    ];
                  }
                }

                final rows = <Widget>[
                  if (visibleDaily.isNotEmpty) ...[
                    const _SectionHeader('Dias'),
                    for (final session in visibleDaily)
                      _SessionItem(
                        session: session,
                        selected: session.id == selected,
                        hasNovelty: session.unread,
                        onTap: () => select(session.id),
                        onRename: null,
                        onDelete: null,
                      ),
                    if (hiddenDays > 0 || _daysExpanded)
                      _DaysToggle(
                        expanded: _daysExpanded,
                        hidden: hiddenDays,
                        onTap: () =>
                            setState(() => _daysExpanded = !_daysExpanded),
                      ),
                  ],
                  if (filtered.isNotEmpty) ...[
                    if (daily.isNotEmpty) const _SectionHeader('Conversas'),
                    for (final session in filtered)
                      _SessionItem(
                        session: session,
                        selected: session.id == selected,
                        hasNovelty: session.unread,
                        onTap: () => select(session.id),
                        onRename: () => _rename(session),
                        onDelete: () => _delete(session),
                      ),
                  ],
                ];
                return ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (context, index) => rows[index],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionItem extends StatefulWidget {
  final AgentSession session;
  final bool selected;

  /// Convite ao ponto de novidade (`unread` do servidor).
  final bool hasNovelty;
  final VoidCallback onTap;

  /// Nulas na conversa do dia (não se renomeia nem apaga).
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  const _SessionItem({
    required this.session,
    required this.selected,
    required this.hasNovelty,
    required this.onTap,
    this.onRename,
    this.onDelete,
  });

  @override
  State<_SessionItem> createState() => _SessionItemState();
}

class _SessionItemState extends State<_SessionItem> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showActions =
        (_hovering || widget.selected) && widget.onRename != null;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: InkWell(
        onTap: widget.onTap,
        child: Container(
          color: widget.selected ? BmoColors.screenBgElevated : null,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.session.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: widget.selected
                        ? BmoColors.accentGreen
                        : BmoColors.textPrimary,
                  ),
                ),
              ),
              if (widget.hasNovelty)
                const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Icon(
                    Icons.circle,
                    size: 7,
                    color: BmoColors.accentGreen,
                  ),
                ),
              if (showActions) ...[
                IconButton(
                  tooltip: 'renomear',
                  iconSize: 16,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.edit_outlined,
                      color: BmoColors.textMuted),
                  onPressed: widget.onRename,
                ),
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'apagar',
                  iconSize: 16,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.delete_outline,
                      color: BmoColors.textMuted),
                  onPressed: widget.onDelete,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RenameSessionDialog extends StatefulWidget {
  final String currentName;

  const _RenameSessionDialog({required this.currentName});

  @override
  State<_RenameSessionDialog> createState() => _RenameSessionDialogState();
}

class _RenameSessionDialogState extends State<_RenameSessionDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentName);
    _controller.selection =
        TextSelection.collapsed(offset: _controller.text.length);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: BmoColors.screenBgElevated,
      title: const Text('Renomear conversa'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 100,
        decoration: const InputDecoration(hintText: 'nome'),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

/// Cabeçalho de seção da lista ("Dias" / "Conversas").
class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: BmoColors.textMuted,
              letterSpacing: 1,
            ),
      ),
    );
  }
}

/// "Mais dias (N)" / "Menos dias": recolhe a cauda da seção Dias.
class _DaysToggle extends StatelessWidget {
  final bool expanded;
  final int hidden;
  final VoidCallback onTap;

  const _DaysToggle({
    required this.expanded,
    required this.hidden,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(
              expanded ? Icons.expand_less : Icons.expand_more,
              size: 16,
              color: BmoColors.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              expanded ? 'Menos dias' : 'Mais dias ($hidden)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: BmoColors.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionsEmpty extends StatelessWidget {
  final String text;

  const _SessionsEmpty({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: BmoColors.textMuted),
      ),
    );
  }
}

class _SessionsError extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _SessionsError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'falha ao carregar',
              style: theme.textTheme.bodySmall?.copyWith(
                color: BmoColors.accentRed,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$error',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: BmoColors.textMuted,
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('tentar novamente')),
          ],
        ),
      ),
    );
  }
}
