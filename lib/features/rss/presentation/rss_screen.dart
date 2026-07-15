import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/bmo_theme.dart';
import '../../../core/widgets/bmo_back_button.dart';
import '../data/models/feed.dart';
import '../data/rss_providers.dart';
import 'selected_view_provider.dart';
import 'widgets/article_list.dart';
import 'widgets/feed_form_modal.dart';

const _kMobileBreakpoint = 600.0;
const _kSidebarWidth = 260.0;

class RssScreen extends ConsumerStatefulWidget {
  const RssScreen({super.key});

  @override
  ConsumerState<RssScreen> createState() => _RssScreenState();
}

class _RssScreenState extends ConsumerState<RssScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final isMobile =
        MediaQuery.of(context).size.width < _kMobileBreakpoint;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.transparent,
      drawer: isMobile
          ? Drawer(
              backgroundColor: BmoColors.screenBg,
              child: RssSidebar(
                onItemTap: () => context.pop(),
              ),
            )
          : null,
      appBar: AppBar(
        backgroundColor: BmoColors.screenBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const BmoBackButton(),
        title: Text(
          'Notícias',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        actions: [
          if (isMobile)
            IconButton(
              icon: const Icon(Icons.menu),
              color: BmoColors.textPrimary,
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline,
                color: BmoColors.accentGreen),
            onPressed: () => _openAddFeedDialog(context),
          ),
        ],
      ),
      body: isMobile
          ? const ArticleList()
          : const _DesktopLayout(),
    );
  }
}

// ============================================================
// Desktop
// ============================================================

class _DesktopLayout extends ConsumerWidget {
  const _DesktopLayout();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(
          width: _kSidebarWidth,
          child: RssSidebar(),
        ),
        VerticalDivider(
          width: 1,
          thickness: 1,
          color: BmoColors.textMuted.withValues(alpha: 0.2),
        ),
        const Expanded(
          child: ArticleList(),
        ),
      ],
    );
  }
}

void _openAddFeedDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => const FeedFormModal(),
  );
}

// ============================================================
// Sidebar
// ============================================================

class RssSidebar extends ConsumerWidget {
  final VoidCallback? onItemTap;

  const RssSidebar({super.key, this.onItemTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final feedsAsync = ref.watch(feedsProvider);
    final currentView = ref.watch(currentRssViewProvider);

    return Container(
      color: BmoColors.screenBg,
      child: Column(
        children: [
          Expanded(
            child: feedsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorState(
                error: e,
                onRetry: () => ref.invalidate(feedsProvider),
              ),
              data: (feeds) => _SidebarContent(
                feeds: feeds,
                currentView: currentView,
                onSelect: (view) {
                  ref.read(currentRssViewProvider.notifier).setView(view);
                  onItemTap?.call();
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

class _SidebarContent extends ConsumerWidget {
  final List<Feed> feeds;
  final RssView currentView;
  final ValueChanged<RssView> onSelect;
  final ThemeData theme;

  const _SidebarContent({
    required this.feeds,
    required this.currentView,
    required this.onSelect,
    required this.theme,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        _SectionHeader(label: 'SMART LISTS', theme: theme),
        _SidebarItem(
          icon: Icons.inbox_outlined,
          label: 'Todos',
          selected: currentView is AllArticles,
          onTap: () => onSelect(const AllArticles()),
          theme: theme,
        ),
        _SidebarItem(
          icon: Icons.markunread_outlined,
          label: 'Não lidos',
          selected: currentView is UnreadArticles,
          onTap: () => onSelect(const UnreadArticles()),
          theme: theme,
        ),
        _SidebarItem(
          icon: Icons.star_outline,
          label: 'Favoritos',
          selected: currentView is StarredArticles,
          onTap: () => onSelect(const StarredArticles()),
          theme: theme,
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Divider(
            color: BmoColors.textMuted,
            height: 1,
          ),
        ),
        _SectionHeader(
          label: 'FEEDS',
          theme: theme,
          trailing: GestureDetector(
            onTap: () => _openFeedForm(context),
            child: const Icon(
              Icons.add_circle_outline,
              size: 18,
              color: BmoColors.accentGreen,
            ),
          ),
        ),
        if (feeds.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              'Nenhum feed cadastrado.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: BmoColors.textMuted,
              ),
            ),
          )
        else
          for (final feed in feeds)
            _SidebarItem(
              icon: Icons.rss_feed,
              label: feed.title,
              selected: switch (currentView) {
                FeedView(:final feedId) => feedId == feed.id,
                _ => false,
              },
              onTap: () => onSelect(FeedView(feed.id)),
              theme: theme,
              trailing: _FeedMenu(
                feed: feed,
                onEdited: () {
                  // Re-select the feed view to refresh the article list
                  if (currentView is FeedView &&
                      (currentView as FeedView).feedId == feed.id) {
                    onSelect(FeedView(feed.id));
                  }
                },
              ),
            ),
      ],
    );
  }

  void _openFeedForm(BuildContext context, {Feed? feed}) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => FeedFormModal(feed: feed),
    );
  }
}

// ============================================================
// Sidebar item (reusable, same pattern as FoldersSidebar)
// ============================================================

class _SidebarItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ThemeData theme;
  final Widget? trailing;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.theme,
    this.trailing,
  });

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
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

// ============================================================
// Section header
// ============================================================

class _SectionHeader extends StatelessWidget {
  final String label;
  final ThemeData theme;
  final Widget? trailing;

  const _SectionHeader({
    required this.label,
    required this.theme,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      child: Row(
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: BmoColors.textMuted,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          if (trailing != null) ...[
            const Spacer(),
            trailing!,
          ],
        ],
      ),
    );
  }
}

// ============================================================
// Feed popup menu (edit / delete)
// ============================================================

class _FeedMenu extends ConsumerWidget {
  final Feed feed;
  final VoidCallback onEdited;

  const _FeedMenu({required this.feed, required this.onEdited});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 16, color: BmoColors.textMuted),
      color: BmoColors.screenBgElevated,
      onSelected: (value) {
        switch (value) {
          case 'edit':
            showDialog(
              context: context,
              barrierColor: Colors.black54,
              builder: (_) => FeedFormModal(feed: feed),
            ).then((didSave) {
              if (didSave == true) onEdited();
            });
          case 'delete':
            _confirmDelete(context, ref);
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'edit', child: Text('Editar')),
        PopupMenuItem(value: 'delete', child: Text('Remover')),
      ],
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BmoColors.screenBgElevated,
        title: const Text(
          'Remover fonte?',
          style: TextStyle(color: BmoColors.textPrimary, fontSize: 14),
        ),
        content: Text(
          "Remover '${feed.title}'? Os artigos dela serão apagados.",
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
              'Remover',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _doDelete(WidgetRef ref) async {
    try {
      await ref.read(feedsProvider.notifier).delete(feed.id);
    } catch (e) {
      // Error is surfaced via the provider's AsyncValue
    }
  }
}

// ============================================================
// Error state
// ============================================================

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
              'falha ao carregar feeds',
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

// ============================================================
// Error state
// ============================================================

