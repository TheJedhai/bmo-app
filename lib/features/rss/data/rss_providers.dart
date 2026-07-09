import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/config/env.dart';
import '../../../core/http/client_factory.dart';
import 'models/article.dart';
import 'models/feed.dart';
import 'rss_client.dart';
import 'rss_repository.dart';

part 'rss_providers.g.dart';

// ============================================================
// Infraestrutura
// ============================================================

final rssClientProvider = Provider<RssClient>((ref) {
  return RssClient(
    client: ref.watch(httpClientProvider),
    baseUrl: Env.bmoServerUrl,
  );
});

final rssRepositoryProvider = Provider<RssRepository>((ref) {
  return RssRepository(ref.watch(rssClientProvider));
});

// ============================================================
// Feeds
// ============================================================

@riverpod
class Feeds extends _$Feeds {
  @override
  Future<List<Feed>> build() async {
    final repo = ref.read(rssRepositoryProvider);
    return repo.listFeeds();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    final repo = ref.read(rssRepositoryProvider);
    state = await AsyncValue.guard(() => repo.listFeeds());
  }

  Future<Feed> create({
    required String title,
    required String url,
    String? siteUrl,
    int? fetchIntervalMinutes,
    int? sortOrder,
    String? tagFilterMode,
    List<String>? tagFilter,
  }) async {
    final repo = ref.read(rssRepositoryProvider);
    final feed = await repo.createFeed(
      title: title,
      url: url,
      siteUrl: siteUrl,
      fetchIntervalMinutes: fetchIntervalMinutes,
      sortOrder: sortOrder,
      tagFilterMode: tagFilterMode,
      tagFilter: tagFilter,
    );
    final current = state.valueOrNull ?? const <Feed>[];
    state = AsyncData([...current, feed]);
    return feed;
  }

  Future<Feed> edit(
    int id, {
    String? title,
    String? url,
    String? siteUrl,
    String? description,
    int? fetchIntervalMinutes,
    bool? isActive,
    int? sortOrder,
    String? tagFilterMode,
    List<String>? tagFilter,
  }) async {
    final repo = ref.read(rssRepositoryProvider);
    final updated = await repo.updateFeed(
      id,
      title: title,
      url: url,
      siteUrl: siteUrl,
      description: description,
      fetchIntervalMinutes: fetchIntervalMinutes,
      isActive: isActive,
      sortOrder: sortOrder,
      tagFilterMode: tagFilterMode,
      tagFilter: tagFilter,
    );
    final current = state.valueOrNull ?? const <Feed>[];
    state = AsyncData([
      for (final f in current)
        if (f.id == id) updated else f,
    ]);
    return updated;
  }

  Future<void> delete(int id) async {
    final repo = ref.read(rssRepositoryProvider);
    await repo.deleteFeed(id);
    final current = state.valueOrNull ?? const <Feed>[];
    state = AsyncData(current.where((f) => f.id != id).toList());
  }

  Future<int> refreshFeed(int id) async {
    final repo = ref.read(rssRepositoryProvider);
    final newCount = await repo.refreshFeed(id);
    // Reload so the list picks up updated lastFetchedAt, etc.
    await refresh();
    return newCount;
  }
}

// ============================================================
// Articles
// ============================================================

typedef ArticlesFilter = ({
  int? feedId,
  bool? isRead,
  bool? isStarred,
  String? titleContains,
});

@riverpod
class Articles extends _$Articles {
  static const _kPageSize = 30;

  int _currentOffset = 0;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  Object? _loadMoreError;

  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  Object? get loadMoreError => _loadMoreError;

  @override
  Future<List<Article>> build(ArticlesFilter filter) async {
    _currentOffset = 0;
    _hasMore = true;
    _isLoadingMore = false;
    _loadMoreError = null;
    final repo = ref.read(rssRepositoryProvider);
    final page = await repo.listArticles(
      feedId: filter.feedId,
      isRead: filter.isRead,
      isStarred: filter.isStarred,
      titleContains: filter.titleContains,
      limit: _kPageSize,
    );
    _currentOffset = page.length;
    _hasMore = page.length == _kPageSize;
    return page;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    _currentOffset = 0;
    _hasMore = true;
    _isLoadingMore = false;
    _loadMoreError = null;
    final repo = ref.read(rssRepositoryProvider);
    state = await AsyncValue.guard(() => repo.listArticles(
          feedId: filter.feedId,
          isRead: filter.isRead,
          isStarred: filter.isStarred,
          titleContains: filter.titleContains,
          limit: _kPageSize,
        ));
    final page = state.valueOrNull ?? const <Article>[];
    _currentOffset = page.length;
    _hasMore = page.length == _kPageSize;
  }

  /// Load the next page of articles and append to the current list.
  ///
  /// Guards against concurrent calls via [_isLoadingMore] and stops when
  /// [_hasMore] is false. Errors are captured in [_loadMoreError] without
  /// replacing the visible list with an AsyncError.
  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    _isLoadingMore = true;
    _loadMoreError = null;
    try {
      final repo = ref.read(rssRepositoryProvider);
      final page = await repo.listArticles(
        feedId: filter.feedId,
        isRead: filter.isRead,
        isStarred: filter.isStarred,
        titleContains: filter.titleContains,
        limit: _kPageSize,
        offset: _currentOffset,
      );
      final current = state.valueOrNull ?? const <Article>[];
      _currentOffset += page.length;
      _hasMore = page.length == _kPageSize;
      state = AsyncData([...current, ...page]);
    } catch (e) {
      _loadMoreError = e;
    } finally {
      _isLoadingMore = false;
    }
  }

  /// Mark a single article as read (or unread).
  Future<Article> markRead(int id, {bool read = true}) async {
    final repo = ref.read(rssRepositoryProvider);
    final updated = await repo.updateArticle(id, isRead: read);
    _replaceArticle(id, updated);
    // If the filter requires unread-only and we just marked it read,
    // remove it from the list.
    if (read && filter.isRead == false) {
      final current = state.valueOrNull ?? const <Article>[];
      state = AsyncData(current.where((a) => a.id != id).toList());
    }
    return updated;
  }

  /// Mark multiple articles as read (batch).
  ///
  /// Accepts either explicit [articleIds], or filter criteria that the
  /// backend uses for a bulk UPDATE.  When [articleIds] is provided the
  /// backend gives it precedence; otherwise the filter params are applied.
  Future<void> markMultipleRead({
    List<int>? articleIds,
    int? feedId,
    bool? isRead,
    bool? isStarred,
    String? titleContains,
  }) async {
    final repo = ref.read(rssRepositoryProvider);
    await repo.markArticlesRead(
      articleIds: articleIds,
      feedId: feedId,
      isRead: isRead,
      isStarred: isStarred,
      titleContains: titleContains,
    );
    await refresh();
  }

  /// Toggle the starred flag on a single article.
  Future<Article> toggleStar(int id) async {
    final repo = ref.read(rssRepositoryProvider);
    final current = state.valueOrNull ?? const <Article>[];
    final existing = current.firstWhere((a) => a.id == id);
    final updated =
        await repo.updateArticle(id, isStarred: !existing.isStarred);
    _replaceArticle(id, updated);
    return updated;
  }

  /// Request an LLM summary for an article and update it locally.
  /// Pass [force] = true to bypass the cache and regenerate.
  Future<({String summary, bool cached})> summarize(int id, {bool force = false}) async {
    final repo = ref.read(rssRepositoryProvider);
    final result = await repo.summarizeArticle(id, force: force);
    final current = state.valueOrNull ?? const <Article>[];
    final idx = current.indexWhere((a) => a.id == id);
    if (idx != -1) {
      final a = current[idx];
      state = AsyncData([
        for (final item in current)
          if (item.id == id)
            Article(
              id: a.id,
              feedId: a.feedId,
              guid: a.guid,
              title: a.title,
              url: a.url,
              author: a.author,
              summaryRaw: a.summaryRaw,
              content: a.content,
              publishedAt: a.publishedAt,
              isRead: a.isRead,
              isStarred: a.isStarred,
              summaryLlm: result.summary,
              summaryLlmAt: DateTime.now(),
              imageUrl: a.imageUrl,
              fullContent: a.fullContent,
              fullContentFetchedAt: a.fullContentFetchedAt,
              createdAt: a.createdAt,
            )
          else
            item,
      ]);
    }
    return result;
  }

  /// Fetch full article content from the source and update it locally.
  Future<({String? fullContent, bool available, bool cached, String? reason})>
      fetchContent(int id) async {
    final repo = ref.read(rssRepositoryProvider);
    final result = await repo.fetchArticleContent(id);
    if (result.available) {
      final current = state.valueOrNull ?? const <Article>[];
      final idx = current.indexWhere((a) => a.id == id);
      if (idx != -1) {
        final a = current[idx];
        state = AsyncData([
          for (final item in current)
            if (item.id == id)
              Article(
                id: a.id,
                feedId: a.feedId,
                guid: a.guid,
                title: a.title,
                url: a.url,
                author: a.author,
                summaryRaw: a.summaryRaw,
                content: a.content,
                publishedAt: a.publishedAt,
                isRead: a.isRead,
                isStarred: a.isStarred,
                summaryLlm: a.summaryLlm,
                summaryLlmAt: a.summaryLlmAt,
                imageUrl: a.imageUrl,
                fullContent: result.fullContent,
                fullContentFetchedAt: DateTime.now(),
                createdAt: a.createdAt,
              )
            else
              item,
        ]);
      }
    }
    return result;
  }

  // ---- helpers ----

  void _replaceArticle(int id, Article updated) {
    final current = state.valueOrNull ?? const <Article>[];
    final idx = current.indexWhere((a) => a.id == id);
    if (idx == -1) return;
    final newList = List<Article>.from(current);
    newList[idx] = updated;
    state = AsyncData(newList);
  }
}

// ============================================================
// Unread count
// ============================================================

@riverpod
Future<int> unreadCount(UnreadCountRef ref) async {
  final repo = ref.read(rssRepositoryProvider);
  return repo.countArticles(isRead: false);
}
