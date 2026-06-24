import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/bmo_theme.dart';
import '../../data/models/folder.dart';
import '../../data/missions_providers.dart';
import '../selected_view_provider.dart';
import 'folder_form_modal.dart';

class FoldersSidebar extends ConsumerWidget {
  final VoidCallback? onItemTap;

  const FoldersSidebar({super.key, this.onItemTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final foldersAsync = ref.watch(foldersProvider);
    final currentView = ref.watch(currentViewProvider);

    return Container(
      color: BmoColors.screenBg,
      child: Column(
        children: [
          Expanded(
            child: foldersAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorState(
                error: e,
                onRetry: () => ref.invalidate(foldersProvider),
              ),
              data: (folders) => _FolderListContent(
                folders: folders,
                currentView: currentView,
                onSelect: (view) {
                  ref.read(currentViewProvider.notifier).setView(view);
                  onItemTap?.call();
                },
                onNewFolder: () {
                  showDialog(
                    context: context,
                    barrierColor: Colors.black54,
                    builder: (_) => const FolderFormModal(),
                  );
                },
                theme: theme,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FolderListContent extends StatelessWidget {
  final List<Folder> folders;
  final MissionsView currentView;
  final ValueChanged<MissionsView> onSelect;
  final VoidCallback onNewFolder;
  final ThemeData theme;

  const _FolderListContent({
    required this.folders,
    required this.currentView,
    required this.onSelect,
    required this.onNewFolder,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        _SectionHeader(label: 'SMART LISTS', theme: theme),
        _FolderItem(
          icon: Icons.inbox_outlined,
          label: 'Todas',
          selected: currentView is AllTasks,
          onTap: () => onSelect(const AllTasks()),
          theme: theme,
        ),
        _FolderItem(
          icon: Icons.today_outlined,
          label: 'Hoje',
          selected: currentView is TodayTasks,
          onTap: () => onSelect(const TodayTasks()),
          theme: theme,
        ),
        _FolderItem(
          icon: Icons.flag_outlined,
          label: 'Urgentes',
          selected: currentView is UrgentTasks,
          onTap: () => onSelect(const UrgentTasks()),
          theme: theme,
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Divider(
            color: BmoColors.textMuted,
            height: 1,
          ),
        ),
        _SectionHeader(label: 'PASTAS', theme: theme),
        for (final folder in folders)
          _FolderItem(
            icon: Icons.folder_outlined,
            label: folder.name,
            selected: switch (currentView) {
              FolderView(:final folderId) => folderId == folder.id,
              _ => false,
            },
            onTap: () => onSelect(FolderView(folder.id)),
            theme: theme,
            trailing: _FolderMenu(folder: folder),
          ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Divider(
            color: BmoColors.textMuted,
            height: 1,
          ),
        ),
        _NewFolderButton(onTap: onNewFolder, theme: theme),
      ],
    );
  }
}

class _FolderItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ThemeData theme;
  final Widget? trailing;

  const _FolderItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.theme,
    this.trailing,
  });

  @override
  State<_FolderItem> createState() => _FolderItemState();
}

class _FolderItemState extends State<_FolderItem> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final bg = widget.selected
        ? BmoColors.screenBgElevated
        : (_hovering
            ? BmoColors.screenBgElevated.withValues(alpha: 0.5)
            : Colors.transparent);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          color: bg,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(
                widget.icon,
                size: 18,
                color: widget.selected
                    ? BmoColors.accentGreen
                    : BmoColors.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: widget.theme.textTheme.bodyMedium?.copyWith(
                    color: widget.selected
                        ? BmoColors.textPrimary
                        : BmoColors.textSecondary,
                    fontWeight:
                        widget.selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              if (widget.trailing != null) widget.trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

class _FolderMenu extends ConsumerWidget {
  final Folder folder;

  const _FolderMenu({required this.folder});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 16, color: BmoColors.textMuted),
      color: BmoColors.screenBgElevated,
      onSelected: (value) {
        switch (value) {
          case 'rename':
            showDialog(
              context: context,
              barrierColor: Colors.black54,
              builder: (_) => FolderFormModal(folder: folder),
            );
          case 'delete':
            _confirmDelete(context, ref);
        }
      },
      itemBuilder: (_) {
        final items = <PopupMenuEntry<String>>[
          const PopupMenuItem(value: 'rename', child: Text('Renomear')),
        ];
        if (!folder.isDefault) {
          items.add(
            const PopupMenuItem(value: 'delete', child: Text('Excluir')),
          );
        }
        return items;
      },
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BmoColors.screenBgElevated,
        title: const Text(
          'Excluir pasta?',
          style: TextStyle(color: BmoColors.textPrimary, fontSize: 14),
        ),
        content: Text(
          "Excluir '${folder.name}'? As tarefas dentro dela também serão removidas.",
          style: const TextStyle(color: BmoColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _doDelete(ref);
            },
            child: const Text(
              'Excluir',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _doDelete(WidgetRef ref) async {
    try {
      await ref.read(foldersProvider.notifier).remove(folder.id);
    } catch (e) {
      // Error is surfaced via the provider's AsyncValue
    }
  }
}

class _NewFolderButton extends StatefulWidget {
  final VoidCallback onTap;
  final ThemeData theme;

  const _NewFolderButton({required this.onTap, required this.theme});

  @override
  State<_NewFolderButton> createState() => _NewFolderButtonState();
}

class _NewFolderButtonState extends State<_NewFolderButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          color: _hovering
              ? BmoColors.screenBgElevated.withValues(alpha: 0.5)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.add, size: 18, color: BmoColors.textMuted),
              const SizedBox(width: 10),
              Text(
                'Nova pasta',
                style: widget.theme.textTheme.bodyMedium?.copyWith(
                  color: BmoColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final ThemeData theme;

  const _SectionHeader({required this.label, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: BmoColors.textMuted,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
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
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 32),
            const SizedBox(height: 8),
            Text(
              'falha ao carregar pastas',
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
