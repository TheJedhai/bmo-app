import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models/article.dart';
import 'models/feed.dart';

class RssApiException implements Exception {
  final int statusCode;
  final String errorCode;
  final String message;

  const RssApiException({
    required this.statusCode,
    required this.errorCode,
    required this.message,
  });

  @override
  String toString() => 'RssApiException($statusCode, $errorCode): $message';
}

class RssClient {
  final http.Client _client;
  final String _baseUrl;

  RssClient({required http.Client client, required String baseUrl})
      : _client = client,
        _baseUrl = baseUrl;

  // ============================================================
  // Feeds
  // ============================================================

  Future<List<Feed>> listFeeds() async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/api/v1/feeds'),
    );
    _ensureOk(response);
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => Feed.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Feed> createFeed({
    required String title,
    required String url,
    String? siteUrl,
    int? fetchIntervalMinutes,
    int? sortOrder,
    String? tagFilterMode,
    List<String>? tagFilter,
  }) async {
    final body = <String, dynamic>{
      'title': title,
      'url': url,
    };
    if (siteUrl != null) body['site_url'] = siteUrl;
    if (fetchIntervalMinutes != null) {
      body['fetch_interval_minutes'] = fetchIntervalMinutes;
    }
    if (sortOrder != null) body['sort_order'] = sortOrder;
    if (tagFilterMode != null) body['tag_filter_mode'] = tagFilterMode;
    if (tagFilter != null) body['tag_filter'] = tagFilter;

    final response = await _client.post(
      Uri.parse('$_baseUrl/api/v1/feeds'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    _ensureOk(response);
    return Feed.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<Feed> updateFeed(
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
    final body = <String, dynamic>{};
    if (title != null) body['title'] = title;
    if (url != null) body['url'] = url;
    if (siteUrl != null) body['site_url'] = siteUrl;
    if (description != null) body['description'] = description;
    if (fetchIntervalMinutes != null) {
      body['fetch_interval_minutes'] = fetchIntervalMinutes;
    }
    if (isActive != null) body['is_active'] = isActive;
    if (sortOrder != null) body['sort_order'] = sortOrder;
    if (tagFilterMode != null) body['tag_filter_mode'] = tagFilterMode;
    if (tagFilter != null) body['tag_filter'] = tagFilter;

    final response = await _client.patch(
      Uri.parse('$_baseUrl/api/v1/feeds/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    _ensureOk(response);
    return Feed.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteFeed(int id) async {
    final response = await _client.delete(
      Uri.parse('$_baseUrl/api/v1/feeds/$id'),
    );
    _ensureOk(response);
  }

  Future<int> refreshFeed(int id) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/api/v1/feeds/$id/refresh'),
      headers: {'Content-Type': 'application/json'},
    );
    _ensureOk(response);
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return decoded['new_count'] as int? ?? 0;
  }

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
  }) async {
    final queryParams = <String, String>{};
    if (feedId != null) queryParams['feed_id'] = feedId.toString();
    if (isRead != null) queryParams['is_read'] = isRead.toString();
    if (isStarred != null) queryParams['is_starred'] = isStarred.toString();
    if (publishedAfter != null) {
      queryParams['published_after'] = _formatDateTime(publishedAfter);
    }
    if (publishedBefore != null) {
      queryParams['published_before'] = _formatDateTime(publishedBefore);
    }
    if (titleContains != null) queryParams['title_contains'] = titleContains;
    if (limit != null) queryParams['limit'] = limit.toString();
    if (offset != null) queryParams['offset'] = offset.toString();

    final uri = Uri.parse('$_baseUrl/api/v1/articles')
        .replace(queryParameters: queryParams.isEmpty ? null : queryParams);

    final response = await _client.get(uri);
    _ensureOk(response);
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => Article.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Article> getArticle(int id) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/api/v1/articles/$id'),
    );
    _ensureOk(response);
    return Article.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<Article> updateArticle(
    int id, {
    bool? isRead,
    bool? isStarred,
  }) async {
    final body = <String, dynamic>{};
    if (isRead != null) body['is_read'] = isRead;
    if (isStarred != null) body['is_starred'] = isStarred;

    final response = await _client.patch(
      Uri.parse('$_baseUrl/api/v1/articles/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    _ensureOk(response);
    return Article.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> markArticlesRead({
    List<int>? articleIds,
    int? feedId,
    bool? isRead,
    bool? isStarred,
    String? titleContains,
  }) async {
    final body = <String, dynamic>{};
    if (articleIds != null) body['article_ids'] = articleIds;
    if (feedId != null) body['feed_id'] = feedId;
    if (isRead != null) body['is_read'] = isRead;
    if (isStarred != null) body['is_starred'] = isStarred;
    if (titleContains != null) body['title_contains'] = titleContains;

    final response = await _client.post(
      Uri.parse('$_baseUrl/api/v1/articles/mark-read'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    _ensureOk(response);
  }

  Future<({String summary, bool cached})> summarizeArticle(int id, {bool force = false}) async {
    final uri = Uri.parse('$_baseUrl/api/v1/articles/$id/summarize')
        .replace(queryParameters: force ? {'force': 'true'} : null);
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
    );
    _ensureOk(response);
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return (
      summary: decoded['summary'] as String? ?? '',
      cached: decoded['cached'] as bool? ?? false,
    );
  }

  Future<int> countArticles({bool? isRead, int? feedId}) async {
    final queryParams = <String, String>{};
    if (isRead != null) queryParams['is_read'] = isRead.toString();
    if (feedId != null) queryParams['feed_id'] = feedId.toString();

    final uri = Uri.parse('$_baseUrl/api/v1/articles/count')
        .replace(queryParameters: queryParams.isEmpty ? null : queryParams);

    final response = await _client.get(uri);
    _ensureOk(response);
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return decoded['count'] as int? ?? 0;
  }

  Future<({String? fullContent, bool available, bool cached, String? reason})>
      fetchArticleContent(int id) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/api/v1/articles/$id/fetch-content'),
      headers: {'Content-Type': 'application/json'},
    );
    _ensureOk(response);
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return (
      fullContent: decoded['full_content'] as String?,
      available: decoded['available'] as bool? ?? false,
      cached: decoded['cached'] as bool? ?? false,
      reason: decoded['reason'] as String?,
    );
  }

  // ============================================================
  // Helpers
  // ============================================================

  void _ensureOk(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    String errorCode = 'unknown';
    String message = response.body;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        errorCode = decoded['error'] as String? ?? 'unknown';
        message = decoded['message'] as String? ?? response.body;
      }
    } catch (_) {
      // corpo não é JSON; usa o body bruto como message
    }
    throw RssApiException(
      statusCode: response.statusCode,
      errorCode: errorCode,
      message: message,
    );
  }
}

String _formatDateTime(DateTime dt) => dt.toUtc().toIso8601String();
