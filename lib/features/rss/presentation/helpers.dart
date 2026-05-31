import 'package:flutter/material.dart';

/// Strip HTML tags and decode common HTML entities.
/// Used to clean RSS summary/content for plain-text display.
String stripHtml(String html) {
  // Remove HTML tags
  final noTags = html.replaceAll(RegExp(r'<[^>]*>'), ' ');
  // Decode common HTML entities
  final decoded = noTags
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&#160;', ' ')
      .replaceAll('&#x27;', "'")
      .replaceAll('&#x2F;', '/')
      .replaceAll('&#x3D;', '=')
      .replaceAll('&#x26;', '&');
  // Collapse whitespace
  final collapsed = decoded.replaceAll(RegExp(r'\s+'), ' ').trim();
  return collapsed;
}

/// Format [dateTime] as a relative string in pt-BR.
///
/// - < 1 min: "agora"
/// - < 60 min: "há Xmin"
/// - < 24h: "há Xh"
/// - < 7d: "há Xd"
/// - same year: "dd/MM HH:mm"
/// - else: "dd/MM/yy"
String formatRelativeDate(DateTime dateTime) {
  final now = DateTime.now();
  final diff = now.difference(dateTime);

  if (diff.isNegative) {
    // Future date — just format
    return _formatAbsolute(dateTime);
  }

  if (diff.inMinutes < 1) return 'agora';
  if (diff.inMinutes < 60) return 'há ${diff.inMinutes}min';
  if (diff.inHours < 24) return 'há ${diff.inHours}h';
  if (diff.inDays < 7) return 'há ${diff.inDays}d';

  return _formatAbsolute(dateTime);
}

/// Split plain text by double newlines into paragraph widgets.
///
/// Used to render fullContent from trafilatura (plain text with \n\n
/// paragraph separators) as proper text blocks.
List<Widget> renderParagraphs(String text, TextStyle style) {
  return text
      .split(RegExp(r'\n\n+'))
      .where((p) => p.trim().isNotEmpty)
      .map((p) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(p.trim(), style: style),
          ))
      .toList();
}

String _formatAbsolute(DateTime dt) {
  final now = DateTime.now();
  final sameYear = dt.year == now.year;
  final month = dt.month.toString().padLeft(2, '0');
  final day = dt.day.toString().padLeft(2, '0');
  final hour = dt.hour.toString().padLeft(2, '0');
  final minute = dt.minute.toString().padLeft(2, '0');

  if (sameYear) {
    return '$day/$month $hour:$minute';
  }
  return '$day/$month/${dt.year.toString().substring(2)}';
}
