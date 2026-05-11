import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/bmo_theme.dart';
import '../data/conversation.dart';
import '../providers/chat_providers.dart';
import 'rename_conversation_dialog.dart';

const _kMobileBreakpoint = 600.0;

class ConversationList extends ConsumerStatefulWidget {
  /// Callback chamado depois que uma conversa é selecionada (ou criada).
  /// Útil pro mobile fechar o drawer.
  final VoidCallback? onItemTap;

  const ConversationList({super.key, this.onItemTap});

  @override
  ConsumerState<ConversationList> createState() => _ConversationListState();
}

class _ConversationListState extends ConsumerState<ConversationList> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Conversation> _filter(List<Conversation> all) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where((c) => c.name.toLowerCase().contains(q))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final conversationsAsync = ref.watch(conversationsProvider);
    final selectedId = ref.watch(selectedConversationIdProvider);

    return Container(
      color: BmoColors.screenBg,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: BmoColors.accentGreen,
                  foregroundColor: const Color(0xFF0F1115),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: Text(
                  'Nova conversa',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: const Color(0xFF0F1115),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: () async {
                  try {
                    final conv = await ref
                        .read(conversationsProvider.notifier)
                        .createNew();
                    ref.read(selectedConversationIdProvider.notifier).state =
                        conv.uuid;
                    widget.onItemTap?.call();
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('falha ao criar: $e')),
                      );
                    }
                  }
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              controller: _searchController,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: BmoColors.textPrimary,
              ),
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'buscar...',
                hintStyle: theme.textTheme.bodySmall?.copyWith(
                  color: BmoColors.textMuted,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  size: 16,
                  color: BmoColors.textMuted,
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        iconSize: 16,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                        tooltip: 'limpar',
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        icon: Icon(
                          Icons.close,
                          color: BmoColors.textMuted,
                        ),
                      ),
                filled: true,
                fillColor: BmoColors.screenBgElevated,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: BmoColors.textMuted.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: BmoColors.accentGreen,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          Divider(
            color: BmoColors.textMuted.withValues(alpha: 0.2),
            height: 1,
          ),
          Expanded(
            child: conversationsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorState(
                error: e,
                onRetry: () => ref.invalidate(conversationsProvider),
              ),
              data: (convs) {
                if (convs.isEmpty) {
                  return _EmptyListState(theme: theme);
                }
                final filtered = _filter(convs);
                if (filtered.isEmpty) {
                  return _NoMatchesState(theme: theme);
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final c = filtered[index];
                    return _ConversationItem(
                      conversation: c,
                      selected: c.uuid == selectedId,
                      onTap: () {
                        ref
                            .read(selectedConversationIdProvider.notifier)
                            .state = c.uuid;
                        widget.onItemTap?.call();
                      },
                      onRename: () => showRenameDialog(context, ref, c),
                      onDelete: () => _confirmAndDelete(context, ref, c),
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

  Future<void> _confirmAndDelete(
    BuildContext context,
    WidgetRef ref,
    Conversation c,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apagar conversa?'),
        content: Text(
          c.name.isEmpty ? 'Esta conversa será removida.' : '"${c.name}" será removida.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(conversationsProvider.notifier).delete(c.uuid);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('falha ao apagar: $e')),
        );
      }
    }
  }
}

class _ConversationItem extends StatefulWidget {
  final Conversation conversation;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _ConversationItem({
    required this.conversation,
    required this.selected,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  @override
  State<_ConversationItem> createState() => _ConversationItemState();
}

class _ConversationItemState extends State<_ConversationItem> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < _kMobileBreakpoint;
    final showActions = isMobile || _hovering || widget.selected;

    final bg = widget.selected
        ? BmoColors.screenBgElevated
        : (_hovering
            ? BmoColors.screenBgElevated.withValues(alpha: 0.5)
            : Colors.transparent);

    final displayName = widget.conversation.name.isEmpty
        ? '(sem nome)'
        : widget.conversation.name;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          color: bg,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: BmoColors.textPrimary,
                    fontWeight:
                        widget.selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              if (showActions) ...[
                IconButton(
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  tooltip: 'Renomear',
                  onPressed: widget.onRename,
                  icon: Icon(
                    Icons.edit_outlined,
                    color: BmoColors.textSecondary,
                  ),
                ),
                IconButton(
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  tooltip: 'Apagar',
                  onPressed: widget.onDelete,
                  icon: Icon(
                    Icons.delete_outline,
                    color: BmoColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyListState extends StatelessWidget {
  final ThemeData theme;
  const _EmptyListState({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Nenhuma conversa ainda',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: BmoColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'comece uma nova',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: BmoColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoMatchesState extends StatelessWidget {
  final ThemeData theme;
  const _NoMatchesState({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Text(
          'Nenhuma conversa encontrada',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: BmoColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.redAccent, size: 32),
            const SizedBox(height: 8),
            Text(
              'falha ao carregar',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.redAccent,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: BmoColors.textMuted,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onRetry,
              child: const Text('tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}
