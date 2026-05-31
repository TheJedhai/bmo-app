import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/bmo_theme.dart';
import '../../data/models/article.dart';
import '../../data/models/feed.dart';
import '../../data/rss_providers.dart';
import '../helpers.dart';
import '../selected_view_provider.dart';
import 'article_detail_modal.dart';

/// Renders the article list for the current [RssView] selection.
///
/// Groups by feed when showing cross-feed views (All, Unread, Starred);
/// shows a flat chronological list when inside a specific feed.
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

        final isFeedView = view is FeedView;
        if (isFeedView) {
          return _FlatArticleList(
            articles: articles,
            onTap: (a) => _openDetail(context, ref, a),
            onStarToggle: (a) =>
                ref.read(articlesProvider(filter).notifier).toggleStar(a.id),
          );
        }

        // Group by feed
        final feedsAsync = ref.watch(feedsProvider);
        final feedMap = <int, Feed>{};
        if (feedsAsync.hasValue) {
          for (final f in feedsAsync.value!) {
            feedMap[f.id] = f;
          }
        }

        final groups = _groupByFeed(articles);
        return _GroupedArticleList(
          groups: groups,
          feedMap: feedMap,
          onTap: (a) => _openDetail(context, ref, a),
          onStarToggle: (a) =>
              ref.read(articlesProvider(filter).notifier).toggleStar(a.id),
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

  // ---- filter mapping (Part A) ----

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
// Grouped list (with feed headers)
// ============================================================

typedef _ArticleAction = void Function(Article article);

Map<Feed, List<Article>> _groupByFeed(List<Article> articles) {
  // We'll use a placeholder for articles without a matched feed.
  // Groups are sorted by the first article's publishedAt within each group.
  final map = <int, List<Article>>{};
  for (final a in articles) {
    map.putIfAbsent(a.feedId, () => []).add(a);
  }
  // Return a LinkedHashMap preserving insertion order.
  // The backend sorts by published_at DESC, so the first article per feed
  // determines group order.
  final result = <Feed, List<Article>>{};
  for (final entry in map.entries) {
    result[Feed(
      id: entry.key,
      title: 'Feed #${entry.key}',
      url: '',
      fetchIntervalMinutes: 60,
      isActive: true,
      sortOrder: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    )] = entry.value;
  }
  return result;
}

class _GroupedArticleList extends StatelessWidget {
  final Map<Feed, List<Article>> groups;
  final Map<int, Feed> feedMap;
  final _ArticleAction onTap;
  final _ArticleAction onStarToggle;

  const _GroupedArticleList({
    required this.groups,
    required this.feedMap,
    required this.onTap,
    required this.onStarToggle,
  });

  @override
  Widget build(BuildContext context) {
    final entries = groups.entries.where((e) => e.value.isNotEmpty).toList();
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: entries.fold<int>(0, (sum, e) => sum + 1 + e.value.length),
      itemBuilder: (context, index) {
        var cursor = 0;
        for (final entry in entries) {
          if (index == cursor) {
            final resolved =
                feedMap[entry.key.id]?.title ?? entry.key.title;
            return _GroupHeader(title: resolved);
          }
          cursor++;
          final articleIndex = index - cursor;
          if (articleIndex < entry.value.length) {
            final article = entry.value[articleIndex];
            return _ArticleCard(
              article: article,
              onTap: () => onTap(article),
              onStarToggle: () => onStarToggle(article),
            );
          }
          cursor += entry.value.length;
        }
        return const SizedBox.shrink();
      },
    );
  }
}

// ============================================================
// Flat list (inside a specific feed, no grouping headers)
// ============================================================

class _FlatArticleList extends StatelessWidget {
  final List<Article> articles;
  final _ArticleAction onTap;
  final _ArticleAction onStarToggle;

  const _FlatArticleList({
    required this.articles,
    required this.onTap,
    required this.onStarToggle,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: articles.length,
      itemBuilder: (context, index) {
        final article = articles[index];
        return _ArticleCard(
          article: article,
          onTap: () => onTap(article),
          onStarToggle: () => onStarToggle(article),
        );
      },
    );
  }
}

// ============================================================
// Group header
// ============================================================

class _GroupHeader extends StatelessWidget {
  final String title;

  const _GroupHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: theme.textTheme.labelMedium?.copyWith(
          color: BmoColors.accentYellow,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ============================================================
// Article card
// ============================================================

class _ArticleCard extends ConsumerWidget {
  final Article article;
  final VoidCallback onTap;
  final VoidCallback onStarToggle;

  const _ArticleCard({
    required this.article,
    required this.onTap,
    required this.onStarToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isRead = article.isRead;
    final isStarred = article.isStarred;

    final titleColor =
        isRead ? BmoColors.textMuted : BmoColors.textPrimary;
    final titleWeight = isRead ? FontWeight.w400 : FontWeight.w600;

    final summary = article.summaryRaw;
    final stripped =
        summary != null && summary.isNotEmpty ? stripHtml(summary) : null;
    final dateText = article.publishedAt != null
        ? formatRelativeDate(article.publishedAt!)
        : '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: BmoColors.screenBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Unread indicator dot
              if (!isRead)
                Padding(
                  padding: const EdgeInsets.only(top: 6, right: 8),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: BmoColors.accentGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
                )
              else
                const SizedBox(width: 16),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: titleColor,
                        fontWeight: titleWeight,
                      ),
                    ),
                    if (stripped != null && stripped.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        stripped,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isRead
                              ? BmoColors.textMuted.withValues(alpha: 0.5)
                              : BmoColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      dateText,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: BmoColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              // Star icon
              GestureDetector(
                onTap: onStarToggle,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8, top: 4),
                  child: Icon(
                    isStarred ? Icons.star : Icons.star_border,
                    size: 18,
                    color: isStarred
                        ? BmoColors.accentYellow
                        : BmoColors.textMuted.withValues(alpha: 0.4),
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
