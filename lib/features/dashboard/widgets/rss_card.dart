import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/app_tab.dart';
import '../../../core/navigation/tab_provider.dart';
import '../../../core/theme/bmo_theme.dart';
import '../../rss/data/models/article.dart';
import '../../rss/data/models/feed.dart';
import '../../rss/data/rss_providers.dart';

/// Card de notícias não lidas — span 2×2.
///
/// Mostra a contagem de artigos não lidos em destaque e os títulos dos
/// 3 artigos não lidos mais recentes, com nome do feed. Toque navega
/// para a aba Notícias.
class RssCard extends ConsumerWidget {
  const RssCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCountAsync = ref.watch(unreadCountProvider);
    final unreadArticlesAsync = ref.watch(
      articlesProvider(const (
        isRead: false,
        feedId: null,
        isStarred: null,
        titleContains: null,
      )),
    );
    final feedsAsync = ref.watch(feedsProvider);

    // Se algum dos providers está carregando ou erro
    final allAsync = _combine(unreadCountAsync, unreadArticlesAsync, feedsAsync);

    return allAsync.when(
      loading: () => const _LoadingState(),
      error: (_, _) => const _ErrorState(),
      data: (_) {
        final count = unreadCountAsync.valueOrNull ?? 0;
        final articles = unreadArticlesAsync.valueOrNull ?? [];
        final feeds = feedsAsync.valueOrNull ?? [];

        return _RssContent(
          unreadCount: count,
          articles: articles,
          feeds: feeds,
        );
      },
    );
  }

  /// Combina múltiplos AsyncValues — retorna loading se qualquer um
  /// estiver carregando, error se qualquer um tiver erro, data caso contrário.
  AsyncValue<void> _combine(
    AsyncValue<int> a,
    AsyncValue<List<Article>> b,
    AsyncValue<List<Feed>> c,
  ) {
    if (a.isLoading || b.isLoading || c.isLoading) return const AsyncLoading();
    if (a.hasError) return AsyncValue.error(a.error!, StackTrace.empty);
    if (b.hasError) return AsyncValue.error(b.error!, StackTrace.empty);
    if (c.hasError) return AsyncValue.error(c.error!, StackTrace.empty);
    return const AsyncData(null);
  }
}

class _RssContent extends ConsumerWidget {
  const _RssContent({
    required this.unreadCount,
    required this.articles,
    required this.feeds,
  });

  final int unreadCount;
  final List<Article> articles;
  final List<Feed> feeds;

  String _feedName(int feedId) {
    return feeds
        .where((f) => f.id == feedId)
        .map((f) => f.title)
        .firstOrNull ??
        '';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = articles.take(3).toList();

    return GestureDetector(
      onTap: () => ref.read(currentTabProvider.notifier).setTab(AppTab.rss),
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Contagem em destaque
          Text(
            '$unreadCount',
            style: const TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 40,
              color: BmoColors.accentYellow,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            unreadCount == 1 ? 'artigo não lido' : 'artigos não lidos',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: BmoColors.textSecondary,
            ),
          ),
          if (recent.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(color: BmoColors.textMuted, height: 1),
            const SizedBox(height: 12),
            ...recent.map((article) => _ArticleRow(
                  article: article,
                  feedName: _feedName(article.feedId),
                )),
          ] else if (unreadCount > 0) ...[
            const SizedBox(height: 16),
            Text(
              'Artigos carregando...',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: BmoColors.textMuted.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ArticleRow extends StatelessWidget {
  const _ArticleRow({required this.article, required this.feedName});

  final Article article;
  final String feedName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            article.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: BmoColors.textPrimary,
            ),
          ),
          if (feedName.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              feedName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: BmoColors.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(
        child: Text(
          '—',
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 40,
            color: BmoColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(
        child: Text(
          '—',
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 40,
            color: BmoColors.textMuted,
          ),
        ),
      ),
    );
  }
}
