import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/bmo_theme.dart';
import '../data/models/feed.dart';
import '../data/rss_providers.dart';
import 'selected_view_provider.dart';

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

    if (isMobile) {
      return _MobileLayout(scaffoldKey: _scaffoldKey);
    }
    return const _DesktopLayout();
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
          child: _ContentArea(),
        ),
      ],
    );
  }
}

// ============================================================
// Mobile
// ============================================================

class _MobileLayout extends ConsumerWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;

  const _MobileLayout({required this.scaffoldKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final view = ref.watch(currentRssViewProvider);

    final title = switch (view) {
      AllArticles() => 'Todos',
      UnreadArticles() => 'Não lidos',
      StarredArticles() => 'Favoritos',
      FeedView() => 'Feed',
    };

    return Scaffold(
      key: scaffoldKey,
      backgroundColor: Colors.transparent,
      drawer: Drawer(
        backgroundColor: BmoColors.screenBg,
        child: RssSidebar(
          onItemTap: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      appBar: AppBar(
        backgroundColor: BmoColors.screenBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            color: BmoColors.textPrimary,
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Text(
          title,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: BmoColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: const _ContentArea(),
    );
  }
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

class _SidebarContent extends StatelessWidget {
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
  Widget build(BuildContext context) {
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
        _SectionHeader(label: 'FEEDS', theme: theme),
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
            ),
      ],
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

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.theme,
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
// Content area (placeholder for now — article list comes in 7d)
// ============================================================

class _ContentArea extends ConsumerWidget {
  const _ContentArea();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(currentRssViewProvider);
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.rss_feed,
            size: 48,
            color: BmoColors.textMuted.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'Selecione uma lista ou fonte',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: BmoColors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            switch (view) {
              AllArticles() => 'Todos os artigos',
              UnreadArticles() => 'Apenas não lidos',
              StarredArticles() => 'Apenas favoritos',
              FeedView(:final feedId) => 'Feed #$feedId',
            },
            style: theme.textTheme.bodySmall?.copyWith(
              color: BmoColors.textMuted.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
