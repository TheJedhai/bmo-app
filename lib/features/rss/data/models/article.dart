final class Article {
  final int id;
  final int feedId;
  final String guid;
  final String title;
  final String? url;
  final String? author;
  final String? summaryRaw;
  final String? content;
  final DateTime? publishedAt;
  final bool isRead;
  final bool isStarred;
  final String? summaryLlm;
  final DateTime? summaryLlmAt;
  final String? imageUrl;
  final String? fullContent;
  final DateTime? fullContentFetchedAt;
  final DateTime createdAt;

  const Article({
    required this.id,
    required this.feedId,
    required this.guid,
    required this.title,
    this.url,
    this.author,
    this.summaryRaw,
    this.content,
    this.publishedAt,
    required this.isRead,
    required this.isStarred,
    this.summaryLlm,
    this.summaryLlmAt,
    this.imageUrl,
    this.fullContent,
    this.fullContentFetchedAt,
    required this.createdAt,
  });

  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      id: json['id'] as int? ?? 0,
      feedId: json['feed_id'] as int? ?? 0,
      guid: json['guid'] as String? ?? '',
      title: json['title'] as String? ?? '',
      url: json['url'] as String?,
      author: json['author'] as String?,
      summaryRaw: json['summary_raw'] as String?,
      content: json['content'] as String?,
      publishedAt: json['published_at'] is String
          ? DateTime.tryParse(json['published_at'] as String)
          : null,
      isRead: json['is_read'] as bool? ?? false,
      isStarred: json['is_starred'] as bool? ?? false,
      summaryLlm: json['summary_llm'] as String?,
      summaryLlmAt: json['summary_llm_at'] is String
          ? DateTime.tryParse(json['summary_llm_at'] as String)
          : null,
      imageUrl: json['image_url'] as String?,
      fullContent: json['full_content'] as String?,
      fullContentFetchedAt: json['full_content_fetched_at'] is String
          ? DateTime.tryParse(json['full_content_fetched_at'] as String)
          : null,
      createdAt: _parseDateTime(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'feed_id': feedId,
      'guid': guid,
      'title': title,
      if (url != null) 'url': url,
      if (author != null) 'author': author,
      if (summaryRaw != null) 'summary_raw': summaryRaw,
      if (content != null) 'content': content,
      if (publishedAt != null) 'published_at': _formatDateTime(publishedAt!),
      'is_read': isRead,
      'is_starred': isStarred,
      if (summaryLlm != null) 'summary_llm': summaryLlm,
      if (summaryLlmAt != null) 'summary_llm_at': _formatDateTime(summaryLlmAt!),
      if (imageUrl != null) 'image_url': imageUrl,
      if (fullContent != null) 'full_content': fullContent,
      if (fullContentFetchedAt != null)
        'full_content_fetched_at': _formatDateTime(fullContentFetchedAt!),
      'created_at': _formatDateTime(createdAt),
    };
  }

  @override
  String toString() => 'Article(id=$id, title="$title")';
}

DateTime _parseDateTime(dynamic value) {
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value) ?? DateTime.now();
  }
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(
      (value * 1000).toInt(),
      isUtc: true,
    );
  }
  return DateTime.now();
}

String _formatDateTime(DateTime dt) => dt.toUtc().toIso8601String();
