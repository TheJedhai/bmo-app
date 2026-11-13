import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/bmo_theme.dart';
import '../data/agent_session.dart';
import '../providers/agent_chat_providers.dart';

/// Sidebar de sessões do chat v2: nova, renomear, apagar e buscar.
class AgentSessionList extends ConsumerStatefulWidget {
  final VoidCallback? onItemTap;

  const AgentSessionList({super.key, this.onItemTap});

  @override
  ConsumerState<AgentSessionList> createState() => _AgentSessionListState();
}

class _AgentSessionListState extends ConsumerState<AgentSessionList> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Conversa nova: sem sessão ainda. O servidor cria a sessão no primeiro
  /// envio (que vai com `session_id: null`) e a lista é atualizada no
  /// `turn.start`.
  void _create() {
    ref.read(selectedAgentSessionProvider.notifier).state = null;
    widget.onItemTap?.call();
  }

  Future<void> _rename(AgentSession session) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _RenameSessionDialog(currentName: session.title),
    );
    if (name == null || name.trim().isEmpty) return;
    try {
      await ref.read(agentSessionsProvider.notifier).rename(session.id, name.trim());
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
      await ref.read(agentSessionsProvider.notifier).delete(session.id);
      if (ref.read(selectedAgentSessionProvider) == session.id) {
        ref.read(selectedAgentSessionProvider.notifier).state = null;
      }
    } catch (e) {
      _snack('falha ao apagar: $e');
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sessionsAsync = ref.watch(agentSessionsProvider);
    final selected = ref.watch(selectedAgentSessionProvider);

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
                onRetry: () => ref.invalidate(agentSessionsProvider),
              ),
              data: (sessions) {
                final filtered = _query.isEmpty
                    ? sessions
                    : sessions
                        .where((s) =>
                            s.title.toLowerCase().contains(_query.toLowerCase()))
                        .toList();
                if (sessions.isEmpty) {
                  return const _SessionsEmpty(
                    text: 'nenhuma conversa ainda',
                  );
                }
                if (filtered.isEmpty) {
                  return const _SessionsEmpty(text: 'nada encontrado');
                }
                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final session = filtered[index];
                    return _SessionItem(
                      session: session,
                      selected: session.id == selected,
                      onTap: () {
                        ref.read(selectedAgentSessionProvider.notifier).state =
                            session.id;
                        widget.onItemTap?.call();
                      },
                      onRename: () => _rename(session),
                      onDelete: () => _delete(session),
                    );
                  },
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
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _SessionItem({
    required this.session,
    required this.selected,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  @override
  State<_SessionItem> createState() => _SessionItemState();
}

class _SessionItemState extends State<_SessionItem> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showActions = _hovering || widget.selected;

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
