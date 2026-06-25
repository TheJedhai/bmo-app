import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/bmo_theme.dart';
import '../../data/image_proxy.dart';
import '../../data/models/article.dart';
import '../../data/rss_providers.dart';
import '../helpers.dart';
import '../selected_view_provider.dart';
import 'article_detail_modal.dart';

/// Renders the article list for the current [RssView] selection.
///
/// Uses a responsive grid: 4 cols on wide desktop, 3 on normal desktop,
/// 2 on tablet, 1 on mobile. Cards are sorted by date (newest first);
/// each card shows which feed it belongs to — no grouping headers in grid.
class ArticleList extends ConsumerWidget {
  const ArticleList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(currentRssViewProvider);
    final filter = _viewToFilter(view);

    final articlesAsync = ref.watch(articlesProvider(filter));
    final articlesNotifier = ref.read(articlesProvider(filter).notifier);

    return articlesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorState(
        error: e,
        onRetry: () => articlesNotifier.refresh(),
      ),
      data: (articles) {
        if (articles.isEmpty) {
          return _EmptyState(view: view);
        }

        // Resolve feed names for cross-feed views
        final feedsAsync = ref.watch(feedsProvider);
        final feedMap = <int, String>{};
        if (feedsAsync.hasValue) {
          for (final f in feedsAsync.value!) {
            feedMap[f.id] = f.title;
          }
        }

        return Column(
          children: [
            _ArticleListHeader(
              view: view,
              articleIds: articles.map((a) => a.id).toList(),
            ),
            Expanded(
              child: _ArticleGrid(
                articles: articles,
                feedMap: feedMap,
                onTap: (a) => _openDetail(context, ref, a),
                onStarToggle: (a) =>
                    ref.read(articlesProvider(filter).notifier).toggleStar(a.id),
                onReadToggle: (a) =>
                    ref.read(articlesProvider(filter).notifier).markRead(a.id, read: !a.isRead),
              ),
            ),
          ],
        );
      },
    );
  }

  void _openDetail(BuildContext context, WidgetRef ref, Article article) {
    final view = ref.read(currentRssViewProvider);
    final filter = _viewToFilter(view);

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => ArticleDetailModal(
        article: article,
        filter: filter,
      ),
    );
  }

  // ---- filter mapping ----

  static ({
    int? feedId,
    bool? isRead,
    bool? isStarred,
    String? titleContains,
  }) _viewToFilter(RssView view) {
    return switch (view) {
      AllArticles() => (
          feedId: null,
          isRead: null,
          isStarred: null,
          titleContains: null,
        ),
      UnreadArticles() => (
          feedId: null,
          isRead: false,
          isStarred: null,
          titleContains: null,
        ),
      StarredArticles() => (
          feedId: null,
          isRead: null,
          isStarred: true,
          titleContains: null,
        ),
      FeedView(:final feedId) => (
          feedId: feedId,
          isRead: null,
          isStarred: null,
          titleContains: null,
        ),
    };
  }
}

// ============================================================
// Responsive grid
// ============================================================

class _ArticleGrid extends StatelessWidget {
  final List<Article> articles;
  final Map<int, String> feedMap;
  final void Function(Article) onTap;
  final void Function(Article) onStarToggle;
  final void Function(Article) onReadToggle;

  const _ArticleGrid({
    required this.articles,
    required this.feedMap,
    required this.onTap,
    required this.onStarToggle,
    required this.onReadToggle,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;

        // Determine column count from actual available width
        final crossAxisCount = availableWidth < 450
            ? 1
            : availableWidth < 720
                ? 2
                : availableWidth < 1000
                    ? 3
                    : 4;

        // Compute card width so we can target a consistent card height (~300px)
        final totalHorizontalPadding = 16.0; // left + right padding
        final crossAxisSpacing = 12.0;
        final cardWidth = (availableWidth -
                totalHorizontalPadding -
                (crossAxisCount - 1) * crossAxisSpacing) /
            crossAxisCount;

        // Image is 150px, content area ~150px → target height ~300px
        const targetCardHeight = 300.0;
        final childAspectRatio = cardWidth / targetCardHeight;

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: crossAxisSpacing,
            crossAxisSpacing: crossAxisSpacing,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: articles.length,
          itemBuilder: (context, index) {
            final article = articles[index];
            final feedName =
                feedMap[article.feedId] ?? 'Feed #${article.feedId}';
            return _ArticleCard(
              article: article,
              feedName: feedName,
              onTap: () => onTap(article),
              onStarToggle: () => onStarToggle(article),
              onReadToggle: () => onReadToggle(article),
            );
          },
        );
      },
    );
  }
}

// ============================================================
// Article card (news-card style)
// ============================================================

class _ArticleCard extends ConsumerWidget {
  final Article article;
  final String feedName;
  final VoidCallback onTap;
  final VoidCallback onStarToggle;
  final VoidCallback onReadToggle;

  const _ArticleCard({
    required this.article,
    required this.feedName,
    required this.onTap,
    required this.onStarToggle,
    required this.onReadToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isRead = article.isRead;
    final isStarred = article.isStarred;

    final titleColor = isRead ? BmoColors.textMuted : BmoColors.textPrimary;
    final titleWeight = isRead ? FontWeight.w400 : FontWeight.w600;

    final summary = article.summaryRaw;
    final stripped =
        summary != null && summary.isNotEmpty ? stripHtml(summary) : null;
    final dateText = article.publishedAt != null
        ? formatRelativeDate(article.publishedAt!)
        : '';

    final hasImage =
        article.imageUrl != null && article.imageUrl!.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: isRead
              ? BmoColors.screenBgElevated.withValues(alpha: 0.7)
              : BmoColors.screenBgElevated,
          borderRadius: BorderRadius.circular(10),
          border: !isRead
              ? Border.all(
                  color: BmoColors.accentGreen.withValues(alpha: 0.25),
                  width: 1.5,
                )
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ---- Image (or BMO placeholder) ----
            Expanded(
              flex: 3,
              child: hasImage
                  ? _CardImage(
                      imageUrl: article.imageUrl!,
                      isStarred: isStarred,
                      onStarToggle: onStarToggle,
                      isRead: isRead,
                      onReadToggle: onReadToggle,
                    )
                  : _CardImagePlaceholder(
                      feedName: feedName,
                      isStarred: isStarred,
                      onStarToggle: onStarToggle,
                      isRead: isRead,
                      onReadToggle: onReadToggle,
                    ),
            ),
            // ---- Content ----
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Feed name
                    Text(
                      feedName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: BmoColors.accentGreen,
                        fontWeight: FontWeight.w500,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Title
                    Expanded(
                      child: Text(
                        article.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: titleColor,
                          fontWeight: titleWeight,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ),
                    // Summary (1 line, only if it fits)
                    if (stripped != null && stripped.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        stripped,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: BmoColors.textMuted,
                          fontSize: 10,
                          height: 1.3,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    // Date
                    Text(
                      dateText,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isRead
                            ? BmoColors.textMuted.withValues(alpha: 0.7)
                            : BmoColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Card image (network image with loading/error fallback)
// ============================================================

class _CardImage extends StatelessWidget {
  final String imageUrl;
  final bool isStarred;
  final VoidCallback onStarToggle;
  final bool isRead;
  final VoidCallback onReadToggle;

  const _CardImage({
    required this.imageUrl,
    required this.isStarred,
    required this.onStarToggle,
    required this.isRead,
    required this.onReadToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          articleImageProxyUrl(imageUrl),
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              color: BmoColors.screenBgElevated,
              child: const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: BmoColors.textMuted,
                  ),
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) =>
              _buildPlaceholder(context),
        ),
        // Read badge overlay (top-left)
        Positioned(
          top: 6,
          left: 6,
          child: _ReadBadge(
            isRead: isRead,
            onTap: onReadToggle,
          ),
        ),
        // Star badge overlay
        Positioned(
          top: 6,
          right: 6,
          child: _StarBadge(
            isStarred: isStarred,
            onTap: onStarToggle,
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            BmoColors.screenBgElevated,
            Color(0xFF2D2E33),
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Icon(
              Icons.newspaper,
              size: 36,
              color: BmoColors.textMuted.withValues(alpha: 0.2),
            ),
          ),
          Positioned(
            top: 6,
            left: 6,
            child: _ReadBadge(
              isRead: isRead,
              onTap: onReadToggle,
            ),
          ),
          Positioned(
            top: 6,
            right: 6,
            child: _StarBadge(
              isStarred: isStarred,
              onTap: onStarToggle,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Card image placeholder (no imageUrl — BMO themed)
// ============================================================

class _CardImagePlaceholder extends StatelessWidget {
  final String feedName;
  final bool isStarred;
  final VoidCallback onStarToggle;
  final bool isRead;
  final VoidCallback onReadToggle;

  const _CardImagePlaceholder({
    required this.feedName,
    required this.isStarred,
    required this.onStarToggle,
    required this.isRead,
    required this.onReadToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            BmoColors.screenBgElevated,
            Color(0xFF2D2E33),
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Center: large RSS icon
          Center(
            child: Icon(
              Icons.rss_feed,
              size: 40,
              color: BmoColors.accentGreen.withValues(alpha: 0.12),
            ),
          ),
          // Bottom-left: feed name
          Positioned(
            bottom: 8,
            left: 10,
            right: 36,
            child: Text(
              feedName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: BmoColors.accentGreen.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w500,
                    fontSize: 10,
                  ),
            ),
          ),
          // Read badge top-left
          Positioned(
            top: 6,
            left: 6,
            child: _ReadBadge(
              isRead: isRead,
              onTap: onReadToggle,
            ),
          ),
          // Star badge top-right
          Positioned(
            top: 6,
            right: 6,
            child: _StarBadge(
              isStarred: isStarred,
              onTap: onStarToggle,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Star badge
// ============================================================

class _StarBadge extends StatelessWidget {
  final bool isStarred;
  final VoidCallback onTap;

  const _StarBadge({required this.isStarred, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: BmoColors.screenBg.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          isStarred ? Icons.star : Icons.star_border,
          size: 16,
          color: isStarred
              ? BmoColors.accentYellow
              : BmoColors.textMuted.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

// ============================================================
// Read badge
// ============================================================

class _ReadBadge extends StatelessWidget {
  final bool isRead;
  final VoidCallback onTap;

  const _ReadBadge({required this.isRead, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: BmoColors.screenBg.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          isRead ? Icons.markunread : Icons.drafts,
          size: 16,
          color: isRead
              ? BmoColors.textMuted.withValues(alpha: 0.6)
              : BmoColors.accentGreen,
        ),
      ),
    );
  }
}

// ============================================================
// Article list header (overflow menu)
// ============================================================

class _ArticleListHeader extends ConsumerWidget {
  final RssView view;
  final List<int> articleIds;

  const _ArticleListHeader({
    required this.view,
    required this.articleIds,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ArticleList._viewToFilter(view);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_vert,
              size: 16,
              color: BmoColors.textMuted,
            ),
            color: BmoColors.screenBgElevated,
            onSelected: (value) {
              switch (value) {
                case 'mark_all_read':
                  _confirmMarkAllRead(context, ref, filter);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'mark_all_read',
                child: Text('Marcar todas como lidas'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmMarkAllRead(
    BuildContext context,
    WidgetRef ref,
    ArticlesFilter filter,
  ) {
    final isFeedView = view is FeedView;
    final message = isFeedView
        ? 'Marcar todos os artigos deste feed como lidos?'
        : 'Marcar todos os artigos visíveis como lidos?';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BmoColors.screenBgElevated,
        title: const Text(
          'Marcar todas como lidas?',
          style: TextStyle(color: BmoColors.textPrimary, fontSize: 14),
        ),
        content: Text(
          message,
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
              _doMarkAllRead(ref, filter);
            },
            child: const Text(
              'Marcar todas',
              style: TextStyle(color: BmoColors.accentGreen),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _doMarkAllRead(
    WidgetRef ref,
    ArticlesFilter filter,
  ) async {
    final notifier = ref.read(articlesProvider(filter).notifier);
    switch (view) {
      case FeedView(:final feedId):
        await notifier.markMultipleRead(feedId: feedId);
      default:
        await notifier.markMultipleRead(articleIds: articleIds);
    }
  }
}

// ============================================================
// Error / Empty states
// ============================================================

class _ErrorState extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                color: Colors.redAccent, size: 32),
            const SizedBox(height: 8),
            Text(
              'falha ao carregar artigos',
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

class _EmptyState extends StatelessWidget {
  final RssView view;

  const _EmptyState({required this.view});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final message = switch (view) {
      UnreadArticles() => 'Tudo em dia! Nenhuma notícia não lida.',
      StarredArticles() => 'Nenhum artigo favoritado ainda.',
      AllArticles() => 'Nenhum artigo por aqui.',
      FeedView() => 'Este feed ainda não tem artigos.',
    };

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            switch (view) {
              UnreadArticles() => Icons.check_circle_outline,
              StarredArticles() => Icons.star_outline,
              _ => Icons.rss_feed,
            },
            size: 48,
            color: BmoColors.textMuted.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: BmoColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
