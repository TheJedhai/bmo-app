import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/bmo_theme.dart';
import '../../data/image_proxy.dart';
import '../../data/models/article.dart';
import '../../data/models/feed.dart';
import '../../data/rss_client.dart';
import '../../data/rss_providers.dart';
import '../helpers.dart';
import 'feed_form_modal.dart';

enum _ContentStatus { idle, loading, available, unavailable }

class ArticleDetailModal extends ConsumerStatefulWidget {
  final Article article;
  final ({
    int? feedId,
    bool? isRead,
    bool? isStarred,
    String? titleContains,
  }) filter;

  const ArticleDetailModal({
    super.key,
    required this.article,
    required this.filter,
  });

  @override
  ConsumerState<ArticleDetailModal> createState() =>
      _ArticleDetailModalState();
}

class _ArticleDetailModalState extends ConsumerState<ArticleDetailModal> {
  bool _summarizing = false;
  String? _summarizeError;
  _ContentStatus _contentStatus = _ContentStatus.idle;
  String? _contentReason;

  @override
  void initState() {
    super.initState();
    // Mark as read on open
    _markRead();
    // Fetch full content if not already present
    if (widget.article.fullContent != null &&
        widget.article.fullContent!.isNotEmpty) {
      _contentStatus = _ContentStatus.available;
    } else {
      _fetchContent();
    }
  }

  Future<void> _markRead() async {
    if (!widget.article.isRead) {
      try {
        await ref
            .read(articlesProvider(widget.filter).notifier)
            .markRead(widget.article.id, read: true);
      } catch (_) {
        // Silently ignore — read status is cosmetic
      }
    }
  }

  Future<void> _fetchContent() async {
    if (_contentStatus == _ContentStatus.loading) return;

    setState(() {
      _contentStatus = _ContentStatus.loading;
      _contentReason = null;
    });

    try {
      final result = await ref
          .read(articlesProvider(widget.filter).notifier)
          .fetchContent(widget.article.id);
      if (!mounted) return;
      setState(() {
        if (result.available) {
          _contentStatus = _ContentStatus.available;
        } else {
          _contentStatus = _ContentStatus.unavailable;
          _contentReason = result.reason;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _contentStatus = _ContentStatus.unavailable;
        _contentReason = 'Falha na conexão ao buscar conteúdo.';
      });
    }
  }

  Future<void> _summarize({bool force = false}) async {
    setState(() {
      _summarizing = true;
      _summarizeError = null;
    });

    try {
      await ref
          .read(articlesProvider(widget.filter).notifier)
          .summarize(widget.article.id, force: force);
    } catch (e) {
      setState(() {
        _summarizeError = _friendlySummarizeError(e);
      });
    } finally {
      if (mounted) {
        setState(() => _summarizing = false);
      }
    }
  }

  String _friendlySummarizeError(Object e) {
    final s = e.toString();
    if (s.contains('503') || s.contains('unavailable')) {
      return 'O resumidor (DeepSeek) está indisponível no momento. '
          'Tente novamente em alguns instantes.';
    }
    if (s.contains('504') || s.contains('timeout')) {
      return 'O resumo demorou demais. O artigo pode ser muito longo '
          'ou o serviço estar sobrecarregado.';
    }
    return 'Não foi possível gerar o resumo: $s';
  }

  void _toggleStar() {
    ref
        .read(articlesProvider(widget.filter).notifier)
        .toggleStar(widget.article.id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Dialog(
      backgroundColor: BmoColors.screenBg,
      insetPadding: isMobile
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 64, vertical: 32),
      shape: isMobile
          ? null
          : RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: isMobile
          ? _MobileDetail(
              article: widget.article,
              filter: widget.filter,
              summarizing: _summarizing,
              summarizeError: _summarizeError,
              contentStatus: _contentStatus,
              contentReason: _contentReason,
              onSummarize: () => _summarize(),
              onForceSummarize: () => _summarize(force: true),
              onStarToggle: _toggleStar,
              theme: theme,
            )
          : _DesktopDetail(
              article: widget.article,
              filter: widget.filter,
              summarizing: _summarizing,
              summarizeError: _summarizeError,
              contentStatus: _contentStatus,
              contentReason: _contentReason,
              onSummarize: () => _summarize(),
              onForceSummarize: () => _summarize(force: true),
              onStarToggle: _toggleStar,
              theme: theme,
            ),
    );
  }
}

// ============================================================
// Desktop layout
// ============================================================

class _DesktopDetail extends StatelessWidget {
  final Article article;
  final dynamic filter;
  final bool summarizing;
  final String? summarizeError;
  final _ContentStatus contentStatus;
  final String? contentReason;
  final VoidCallback onSummarize;
  final VoidCallback onForceSummarize;
  final VoidCallback onStarToggle;
  final ThemeData theme;

  const _DesktopDetail({
    required this.article,
    required this.filter,
    required this.summarizing,
    required this.summarizeError,
    required this.contentStatus,
    required this.contentReason,
    required this.onSummarize,
    required this.onForceSummarize,
    required this.onStarToggle,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage =
        article.imageUrl != null && article.imageUrl!.isNotEmpty;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Image at top
          if (hasImage)
            _DetailImage(imageUrl: article.imageUrl!),
          _DetailAppBar(
            article: article,
            onStarToggle: onStarToggle,
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: _DetailBody(
                article: article,
                filter: filter,
                summarizing: summarizing,
                summarizeError: summarizeError,
                contentStatus: contentStatus,
                contentReason: contentReason,
                onSummarize: onSummarize,
                onForceSummarize: onForceSummarize,
                theme: theme,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Mobile layout (full screen)
// ============================================================

class _MobileDetail extends StatelessWidget {
  final Article article;
  final dynamic filter;
  final bool summarizing;
  final String? summarizeError;
  final _ContentStatus contentStatus;
  final String? contentReason;
  final VoidCallback onSummarize;
  final VoidCallback onForceSummarize;
  final VoidCallback onStarToggle;
  final ThemeData theme;

  const _MobileDetail({
    required this.article,
    required this.filter,
    required this.summarizing,
    required this.summarizeError,
    required this.contentStatus,
    required this.contentReason,
    required this.onSummarize,
    required this.onForceSummarize,
    required this.onStarToggle,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage =
        article.imageUrl != null && article.imageUrl!.isNotEmpty;
    return Scaffold(
      backgroundColor: BmoColors.screenBg,
      appBar: AppBar(
        backgroundColor: BmoColors.screenBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: BmoColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(
              article.isStarred ? Icons.star : Icons.star_border,
              color: article.isStarred
                  ? BmoColors.accentYellow
                  : BmoColors.textMuted,
            ),
            onPressed: onStarToggle,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image at top
            if (hasImage)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _DetailImage(imageUrl: article.imageUrl!),
              ),
            _DetailBody(
              article: article,
              filter: filter,
              summarizing: summarizing,
              summarizeError: summarizeError,
              contentStatus: contentStatus,
              contentReason: contentReason,
              onSummarize: onSummarize,
              onForceSummarize: onForceSummarize,
              theme: theme,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// AppBar (desktop)
// ============================================================

class _DetailAppBar extends StatelessWidget {
  final Article article;
  final VoidCallback onStarToggle;

  const _DetailAppBar({
    required this.article,
    required this.onStarToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 12, 0),
      child: Row(
        children: [
          const Spacer(),
          IconButton(
            icon: Icon(
              article.isStarred ? Icons.star : Icons.star_border,
              color: article.isStarred
                  ? BmoColors.accentYellow
                  : BmoColors.textMuted,
            ),
            onPressed: onStarToggle,
            tooltip: 'Favoritar',
          ),
          IconButton(
            icon: const Icon(Icons.close, color: BmoColors.textMuted),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Detail body
// ============================================================

class _DetailBody extends ConsumerWidget {
  final Article article;
  final dynamic filter;
  final bool summarizing;
  final String? summarizeError;
  final _ContentStatus contentStatus;
  final String? contentReason;
  final VoidCallback onSummarize;
  final VoidCallback onForceSummarize;
  final ThemeData theme;

  const _DetailBody({
    required this.article,
    required this.filter,
    required this.summarizing,
    required this.summarizeError,
    required this.contentStatus,
    required this.contentReason,
    required this.onSummarize,
    required this.onForceSummarize,
    required this.theme,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch for updates from summarize / star toggle / fetchContent
    final currentArticleAsync =
        ref.watch(articlesProvider(filter as ({
          int? feedId,
          bool? isRead,
          bool? isStarred,
          String? titleContains,
        })));
    final currentArticle = currentArticleAsync.hasValue
        ? currentArticleAsync.value!
                .where((a) => a.id == article.id)
                .firstOrNull ??
            article
        : article;

    final author = currentArticle.author;
    final dateStr = currentArticle.publishedAt != null
        ? formatRelativeDate(currentArticle.publishedAt!)
        : '';
    final bodyHtml = (currentArticle.content != null &&
            currentArticle.content!.isNotEmpty)
        ? currentArticle.content
        : currentArticle.summaryRaw;
    final bodyText = bodyHtml != null ? stripHtml(bodyHtml) : '';

    // Resolve feed name + feed object (for tag blocking)
    final feedsAsync = ref.watch(feedsProvider);
    String feedName = 'Feed';
    Feed? feed;
    if (feedsAsync.hasValue) {
      final match = feedsAsync.value!
          .where((f) => f.id == currentArticle.feedId)
          .firstOrNull;
      if (match != null) {
        feedName = match.title;
        feed = match;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(
          currentArticle.title,
          style: theme.textTheme.titleLarge?.copyWith(
            color: BmoColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),

        // Metadata row
        Row(
          children: [
            Icon(Icons.rss_feed,
                size: 14, color: BmoColors.textMuted),
            const SizedBox(width: 4),
            Text(
              feedName,
              style: theme.textTheme.bodySmall?.copyWith(
                color: BmoColors.accentGreen,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (author != null && author.isNotEmpty) ...[
              const SizedBox(width: 16),
              Icon(Icons.person_outline,
                  size: 14, color: BmoColors.textMuted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  author,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: BmoColors.textSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        if (dateStr.isNotEmpty)
          Text(
            dateStr,
            style: theme.textTheme.bodySmall?.copyWith(
              color: BmoColors.textMuted,
              fontSize: 11,
            ),
          ),
        const SizedBox(height: 20),

        // Action buttons
        Row(
          children: [
            _ActionButton(
              icon: Icons.open_in_new,
              label: 'Abrir original',
              onTap: () {
                final url = currentArticle.url;
                if (url != null && url.isNotEmpty) {
                  launchUrl(Uri.parse(url),
                      mode: LaunchMode.externalApplication);
                }
              },
              disabled: currentArticle.url == null ||
                  currentArticle.url!.isEmpty,
              theme: theme,
            ),
            const SizedBox(width: 12),
            _ActionButton(
              icon: summarizing
                  ? Icons.hourglass_empty
                  : Icons.auto_awesome,
              label: summarizing ? 'Resumindo...' : 'Resumir com BMO',
              onTap: summarizing ? null : onSummarize,
              theme: theme,
            ),
          ],
        ),
        const SizedBox(height: 20),

        // LLM Summary
        if (currentArticle.summaryLlm != null &&
            currentArticle.summaryLlm!.isNotEmpty) ...[
          _SummaryBlock(
            text: currentArticle.summaryLlm!,
            summarizing: summarizing,
            onForceSummarize: onForceSummarize,
            theme: theme,
          ),
          const SizedBox(height: 20),
        ],

        // Summarize error
        if (summarizeError != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.redAccent.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline,
                    color: Colors.redAccent, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    summarizeError!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.redAccent,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Divider
        Divider(color: BmoColors.textMuted.withValues(alpha: 0.2)),
        const SizedBox(height: 12),

        // ---- Content section ----

        // Loading
        if (contentStatus == _ContentStatus.loading) ...[
          _ContentLoading(),
          const SizedBox(height: 16),
        ],

        // Full content (available) — rendered as markdown
        if (contentStatus == _ContentStatus.available &&
            currentArticle.fullContent != null &&
            currentArticle.fullContent!.isNotEmpty)
          MarkdownBody(
            data: currentArticle.fullContent!,
            selectable: true,
            styleSheet: _articleBodyMarkdownStyle(theme),
          ),

        // Fallback content (unavailable or idle with body text)
        if ((contentStatus == _ContentStatus.unavailable ||
                contentStatus == _ContentStatus.idle) &&
            bodyText.isNotEmpty) ...[
          if (contentStatus == _ContentStatus.unavailable) ...[
            _FallbackNote(reason: contentReason),
            const SizedBox(height: 16),
          ],
          Text(
            bodyText,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: BmoColors.textPrimary,
              height: 1.6,
            ),
          ),
        ],

        // Truly empty
        if ((contentStatus == _ContentStatus.unavailable ||
                contentStatus == _ContentStatus.idle) &&
            bodyText.isEmpty)
          Text(
            'Sem conteúdo disponível.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: BmoColors.textMuted,
              fontStyle: FontStyle.italic,
            ),
          ),

        // Tags
        if (currentArticle.tags.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'Tags',
            style: theme.textTheme.labelSmall?.copyWith(
              color: BmoColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: currentArticle.tags.map((tag) {
              final normalizedTag = tag.toLowerCase().trim();
              final isBlocked = feed != null &&
                  feed.tagFilterMode == 'block' &&
                  feed.tagFilter.any(
                      (t) => t.toLowerCase().trim() == normalizedTag);
              final isAllowMode =
                  feed != null && feed.tagFilterMode == 'allow';

              if (isBlocked) {
                return _BlockedTagChip(tag: tag, theme: theme);
              }
              return _ClickableTagChip(
                tag: tag,
                theme: theme,
                onTap: () => _showBlockTagDialog(
                  context, ref, feed, tag, isAllowMode),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  // ==========================================================
  // Tag chip helpers
  // ==========================================================

  void _showBlockTagDialog(
    BuildContext context,
    WidgetRef ref,
    Feed? feed,
    String tag,
    bool isAllowMode,
  ) {
    if (feed == null) return;

    if (isAllowMode) {
      _showAllowModeDialog(context, feed);
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BmoColors.screenBgElevated,
        title: const Text(
          'Bloquear tag?',
          style: TextStyle(color: BmoColors.textPrimary, fontSize: 14),
        ),
        content: Text(
          'Novos artigos com a tag "$tag" deixarão de ser baixados neste feed.',
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
              _blockTag(ref, feed, tag, context);
            },
            child: const Text(
              'Bloquear',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  void _showAllowModeDialog(BuildContext context, Feed feed) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BmoColors.screenBgElevated,
        title: const Text(
          'Feed em modo de permissão',
          style: TextStyle(color: BmoColors.textPrimary, fontSize: 14),
        ),
        content: const Text(
          'Este feed está configurado para baixar apenas artigos com as tags '
          'permitidas. Para bloquear esta tag, altere o filtro do feed.',
          style: TextStyle(color: BmoColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Fechar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              showDialog(
                context: context,
                barrierColor: Colors.black54,
                builder: (_) => FeedFormModal(feed: feed),
              );
            },
            child: const Text(
              'Editar feed',
              style: TextStyle(color: BmoColors.accentGreen),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _blockTag(
    WidgetRef ref,
    Feed feed,
    String tag,
    BuildContext context,
  ) async {
    final normalizedTag = tag.toLowerCase().trim();
    final currentFilter =
        feed.tagFilter.map((t) => t.toLowerCase().trim()).toList();
    if (currentFilter.contains(normalizedTag)) return;

    final newTagFilter = [...feed.tagFilter, normalizedTag];
    try {
      await ref.read(feedsProvider.notifier).edit(
            feed.id,
            tagFilterMode: 'block',
            tagFilter: newTagFilter,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tag bloqueada neste feed')),
        );
      }
    } on RssApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }
}

// ============================================================
// Tag chip widgets
// ============================================================

class _BlockedTagChip extends StatelessWidget {
  final String tag;
  final ThemeData theme;

  const _BlockedTagChip({required this.tag, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.5,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: BmoColors.screenBgElevated,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: BmoColors.textMuted.withValues(alpha: 0.15),
          ),
        ),
        child: Text(
          tag,
          style: theme.textTheme.bodySmall?.copyWith(
            color: BmoColors.textMuted,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

class _ClickableTagChip extends StatelessWidget {
  final String tag;
  final ThemeData theme;
  final VoidCallback onTap;

  const _ClickableTagChip({
    required this.tag,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Bloquear tag neste feed',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          mouseCursor: SystemMouseCursors.click,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: BmoColors.screenBgElevated,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: BmoColors.accentGreen.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tag,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: BmoColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.lock_outline,
                  size: 10,
                  color: BmoColors.textMuted.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Action button
// ============================================================

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool disabled;
  final ThemeData theme;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.disabled = false,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = !disabled && onTap != null;
    final color = enabled ? BmoColors.accentGreen : BmoColors.textMuted;

    return OutlinedButton.icon(
      onPressed: enabled ? onTap : null,
      icon: Icon(icon, size: 16, color: color),
      label: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: color,
          fontSize: 12,
        ),
      ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(
          color: color.withValues(alpha: 0.4),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

// ============================================================
// Summary block (BMO AI) — renders markdown, highlights "Contexto do BMO"
// ============================================================

/// Regex that matches the "Contexto do BMO:" section header.
/// Handles bold markers, optional colon, and leading whitespace.
final _contextoRegex = RegExp(
  r'(?:\n|^)\*{0,2}Contexto do BMO:?\*{0,2}\s*',
  multiLine: true,
);

class _SummaryBlock extends StatelessWidget {
  final String text;
  final bool summarizing;
  final VoidCallback onForceSummarize;
  final ThemeData theme;

  const _SummaryBlock({
    required this.text,
    required this.summarizing,
    required this.onForceSummarize,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final match = _contextoRegex.firstMatch(text);

    final String factualPart;
    final String? contextoPart;

    if (match != null) {
      factualPart = text.substring(0, match.start).trimRight();
      contextoPart = text.substring(match.end).trim();
    } else {
      factualPart = text;
      contextoPart = null;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BmoColors.screenBgElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: BmoColors.accentGreen.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with regenerate button
          Row(
            children: [
              const Icon(Icons.auto_awesome,
                  size: 16, color: BmoColors.accentGreen),
              const SizedBox(width: 6),
              Text(
                'Resumo do BMO',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: BmoColors.accentGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (!summarizing)
                GestureDetector(
                  onTap: onForceSummarize,
                  child: Tooltip(
                    message: 'Gerar novo resumo',
                    child: Icon(
                      Icons.refresh,
                      size: 16,
                      color: BmoColors.textMuted.withValues(alpha: 0.7),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Factual part
          if (factualPart.isNotEmpty)
            MarkdownBody(
              data: factualPart,
              selectable: true,
              styleSheet: _summaryMarkdownStyle(theme),
            ),

          // Contexto do BMO block
          if (contextoPart != null && contextoPart.isNotEmpty) ...[
            const SizedBox(height: 12),
            _BmoContextBlock(text: contextoPart, theme: theme),
          ],
        ],
      ),
    );
  }
}

/// Renders the "Contexto do BMO" section in a visually distinct block —
/// a yellow-tinted container with a lightbulb icon to signal that this
/// is the model's commentary/analysis, not factual reporting from the article.
class _BmoContextBlock extends StatelessWidget {
  final String text;
  final ThemeData theme;

  const _BmoContextBlock({required this.text, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BmoColors.accentYellow.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: BmoColors.accentYellow.withValues(alpha: 0.5),
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                size: 15,
                color: BmoColors.accentYellow.withValues(alpha: 0.9),
              ),
              const SizedBox(width: 6),
              Text(
                'Contexto do BMO',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: BmoColors.accentYellow.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          MarkdownBody(
            data: text,
            selectable: true,
            styleSheet: _contextoMarkdownStyle(theme),
          ),
        ],
      ),
    );
  }
}

MarkdownStyleSheet _summaryMarkdownStyle(ThemeData theme) {
  final base = theme.textTheme.bodyMedium?.copyWith(
    color: BmoColors.textPrimary,
    height: 1.5,
  );
  return MarkdownStyleSheet(
    p: base ?? const TextStyle(color: BmoColors.textPrimary, height: 1.5),
    strong: (base ?? const TextStyle()).copyWith(fontWeight: FontWeight.w700),
    listBullet: base,
    h1: theme.textTheme.bodyLarge?.copyWith(
      color: BmoColors.textPrimary,
      fontWeight: FontWeight.w700,
    ),
    h2: theme.textTheme.bodyMedium?.copyWith(
      color: BmoColors.textPrimary,
      fontWeight: FontWeight.w700,
    ),
    h3: theme.textTheme.bodyMedium?.copyWith(
      color: BmoColors.textPrimary,
      fontWeight: FontWeight.w600,
    ),
  );
}

MarkdownStyleSheet _contextoMarkdownStyle(ThemeData theme) {
  final base = theme.textTheme.bodySmall?.copyWith(
    color: BmoColors.accentYellow.withValues(alpha: 0.9),
    height: 1.5,
    fontSize: 12,
  );
  return MarkdownStyleSheet(
    p: base ?? const TextStyle(color: BmoColors.accentYellow, height: 1.5),
    strong: (base ?? const TextStyle()).copyWith(fontWeight: FontWeight.w700),
    listBullet: base,
    h1: theme.textTheme.bodySmall?.copyWith(
      color: BmoColors.accentYellow,
      fontWeight: FontWeight.w700,
      fontSize: 13,
    ),
    h2: theme.textTheme.bodySmall?.copyWith(
      color: BmoColors.accentYellow,
      fontWeight: FontWeight.w700,
      fontSize: 12,
    ),
    h3: theme.textTheme.bodySmall?.copyWith(
      color: BmoColors.accentYellow,
      fontWeight: FontWeight.w600,
      fontSize: 12,
    ),
  );
}

/// Markdown stylesheet for the full article body (trafilatura output).
/// Uses primary text color with comfortable line-height and proportional
/// heading sizes — matches the BMO visual identity without the accent
/// colours used in the summary block.
MarkdownStyleSheet _articleBodyMarkdownStyle(ThemeData theme) {
  final base = theme.textTheme.bodyMedium?.copyWith(
    color: BmoColors.textPrimary,
    height: 1.6,
  );
  final baseStyle =
      base ?? const TextStyle(color: BmoColors.textPrimary, height: 1.6);
  final baseFontSize = baseStyle.fontSize ?? 14;
  return MarkdownStyleSheet(
    p: baseStyle,
    strong: baseStyle.copyWith(fontWeight: FontWeight.w700),
    em: baseStyle.copyWith(fontStyle: FontStyle.italic),
    listBullet: baseStyle,
    h1: baseStyle.copyWith(
      fontSize: baseFontSize * 1.5,
      fontWeight: FontWeight.w700,
    ),
    h2: baseStyle.copyWith(
      fontSize: baseFontSize * 1.3,
      fontWeight: FontWeight.w700,
    ),
    h3: baseStyle.copyWith(
      fontSize: baseFontSize * 1.15,
      fontWeight: FontWeight.w600,
    ),
    h4: baseStyle.copyWith(
      fontSize: baseFontSize * 1.05,
      fontWeight: FontWeight.w600,
    ),
    h5: baseStyle.copyWith(fontWeight: FontWeight.w600),
    h6: baseStyle.copyWith(fontWeight: FontWeight.w600),
    blockquoteDecoration: BoxDecoration(
      border: Border(
        left: BorderSide(
          color: BmoColors.textMuted.withValues(alpha: 0.3),
          width: 3,
        ),
      ),
      color: BmoColors.textMuted.withValues(alpha: 0.05),
    ),
    code: TextStyle(
      color: BmoColors.textPrimary.withValues(alpha: 0.9),
      backgroundColor: BmoColors.screenBgElevated,
      fontSize: baseFontSize * 0.9,
      fontFamily: 'monospace',
    ),
    codeblockDecoration: BoxDecoration(
      color: BmoColors.screenBgElevated,
      borderRadius: BorderRadius.circular(8),
    ),
    horizontalRuleDecoration: BoxDecoration(
      border: Border(
        top: BorderSide(
          color: BmoColors.textMuted.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
    ),
    a: baseStyle.copyWith(
      color: BmoColors.accentGreen.withValues(alpha: 0.9),
      decoration: TextDecoration.underline,
    ),
  );
}

// ============================================================
// Detail image (modal top)
// ============================================================

class _DetailImage extends StatelessWidget {
  final String imageUrl;

  const _DetailImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: Image.network(
        articleImageProxyUrl(imageUrl),
        height: 200,
        width: double.infinity,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            height: 200,
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
        errorBuilder: (context, error, stackTrace) => Container(
          height: 120,
          color: BmoColors.screenBgElevated,
          child: Center(
            child: Icon(
              Icons.rss_feed,
              size: 32,
              color: BmoColors.textMuted.withValues(alpha: 0.3),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Content loading (scraping in progress)
// ============================================================

class _ContentLoading extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: BmoColors.screenBgElevated,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: BmoColors.accentGreen,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Buscando conteúdo completo...',
            style: theme.textTheme.bodySmall?.copyWith(
              color: BmoColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Fallback note (content unavailable)
// ============================================================

class _FallbackNote extends StatelessWidget {
  final String? reason;

  const _FallbackNote({this.reason});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BmoColors.accentYellow.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: BmoColors.accentYellow.withValues(alpha: 0.5),
            width: 3,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              Icons.info_outline,
              size: 16,
              color: BmoColors.accentYellow.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Não foi possível carregar a matéria completa — '
                  'exibindo o resumo disponível.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: BmoColors.accentYellow.withValues(alpha: 0.9),
                    height: 1.4,
                  ),
                ),
                if (reason != null && reason!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    reason!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: BmoColors.textMuted,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  "Toque em 'Abrir original' para ler no site.",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: BmoColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
