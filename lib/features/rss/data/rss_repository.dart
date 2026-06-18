import 'models/article.dart';
import 'models/feed.dart';
import 'rss_client.dart';

/// Thin wrapper over [RssClient]. Exists so the architecture is ready
/// for future caching, offline support, or persistence layers.
class RssRepository {
  final RssClient _client;

  RssRepository(this._client);

  // ============================================================
  // Feeds
  // ============================================================

  Future<List<Feed>> listFeeds() => _client.listFeeds();

  Future<Feed> createFeed({
    required String title,
    required String url,
    String? siteUrl,
    int? fetchIntervalMinutes,
    int? sortOrder,
  }) =>
      _client.createFeed(
        title: title,
        url: url,
        siteUrl: siteUrl,
        fetchIntervalMinutes: fetchIntervalMinutes,
        sortOrder: sortOrder,
      );

  Future<Feed> updateFeed(
    int id, {
    String? title,
    String? url,
    String? siteUrl,
    String? description,
    int? fetchIntervalMinutes,
    bool? isActive,
    int? sortOrder,
  }) =>
      _client.updateFeed(
        id,
        title: title,
        url: url,
        siteUrl: siteUrl,
        description: description,
        fetchIntervalMinutes: fetchIntervalMinutes,
        isActive: isActive,
        sortOrder: sortOrder,
      );

  Future<void> deleteFeed(int id) => _client.deleteFeed(id);

  Future<int> refreshFeed(int id) => _client.refreshFeed(id);

  // ============================================================
  // Articles
  // ============================================================

  Future<List<Article>> listArticles({
    int? feedId,
    bool? isRead,
    bool? isStarred,
    DateTime? publishedAfter,
    DateTime? publishedBefore,
    String? titleContains,
    int? limit,
    int? offset,
  }) =>
      _client.listArticles(
        feedId: feedId,
        isRead: isRead,
        isStarred: isStarred,
        publishedAfter: publishedAfter,
        publishedBefore: publishedBefore,
        titleContains: titleContains,
        limit: limit,
        offset: offset,
      );

  Future<Article> getArticle(int id) => _client.getArticle(id);

  Future<Article> updateArticle(
    int id, {
    bool? isRead,
    bool? isStarred,
  }) =>
      _client.updateArticle(id, isRead: isRead, isStarred: isStarred);

  Future<void> markArticlesRead({List<int>? articleIds, int? feedId}) =>
      _client.markArticlesRead(articleIds: articleIds, feedId: feedId);

  Future<({String summary, bool cached})> summarizeArticle(int id, {bool force = false}) =>
      _client.summarizeArticle(id, force: force);

  Future<int> countArticles({bool? isRead, int? feedId}) =>
      _client.countArticles(isRead: isRead, feedId: feedId);

  Future<({String? fullContent, bool available, bool cached, String? reason})>
      fetchArticleContent(int id) => _client.fetchArticleContent(id);
}
