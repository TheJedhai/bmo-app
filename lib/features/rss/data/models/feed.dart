final class Feed {
  final int id;
  final String title;
  final String url;
  final String? siteUrl;
  final String? description;
  final int fetchIntervalMinutes;
  final DateTime? lastFetchedAt;
  final String? lastError;
  final bool isActive;
  final int sortOrder;
  final String tagFilterMode;
  final List<String> tagFilter;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Feed({
    required this.id,
    required this.title,
    required this.url,
    this.siteUrl,
    this.description,
    required this.fetchIntervalMinutes,
    this.lastFetchedAt,
    this.lastError,
    required this.isActive,
    required this.sortOrder,
    this.tagFilterMode = 'off',
    this.tagFilter = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory Feed.fromJson(Map<String, dynamic> json) {
    return Feed(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      url: json['url'] as String? ?? '',
      siteUrl: json['site_url'] as String?,
      description: json['description'] as String?,
      fetchIntervalMinutes: json['fetch_interval_minutes'] as int? ?? 60,
      lastFetchedAt: json['last_fetched_at'] is String
          ? DateTime.tryParse(json['last_fetched_at'] as String)
          : null,
      lastError: json['last_error'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      sortOrder: json['sort_order'] as int? ?? 0,
      tagFilterMode: json['tag_filter_mode'] as String? ?? 'off',
      tagFilter: (json['tag_filter'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'url': url,
      if (siteUrl != null) 'site_url': siteUrl,
      if (description != null) 'description': description,
      'fetch_interval_minutes': fetchIntervalMinutes,
      if (lastFetchedAt != null) 'last_fetched_at': _formatDateTime(lastFetchedAt!),
      if (lastError != null) 'last_error': lastError,
      'is_active': isActive,
      'sort_order': sortOrder,
      'tag_filter_mode': tagFilterMode,
      'tag_filter': tagFilter,
      'created_at': _formatDateTime(createdAt),
      'updated_at': _formatDateTime(updatedAt),
    };
  }

  @override
  String toString() => 'Feed(id=$id, title="$title")';
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
