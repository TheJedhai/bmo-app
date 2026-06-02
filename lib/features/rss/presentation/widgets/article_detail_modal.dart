import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/bmo_theme.dart';
import '../../data/image_proxy.dart';
import '../../data/models/article.dart';
import '../../data/rss_providers.dart';
import '../helpers.dart';

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

  Future<void> _summarize() async {
    setState(() {
      _summarizing = true;
      _summarizeError = null;
    });

    try {
      await ref
          .read(articlesProvider(widget.filter).notifier)
          .summarize(widget.article.id);
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
              onSummarize: _summarize,
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
              onSummarize: _summarize,
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
  final dynamic filter; // Type would be verbose; only passed through
  final bool summarizing;
  final String? summarizeError;
  final _ContentStatus contentStatus;
  final String? contentReason;
  final VoidCallback onSummarize;
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
  final ThemeData theme;

  const _DetailBody({
    required this.article,
    required this.filter,
    required this.summarizing,
    required this.summarizeError,
    required this.contentStatus,
    required this.contentReason,
    required this.onSummarize,
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

    // Resolve feed name
    final feedsAsync = ref.watch(feedsProvider);
    String feedName = 'Feed';
    if (feedsAsync.hasValue) {
      feedName = feedsAsync.value!
              .where((f) => f.id == currentArticle.feedId)
              .firstOrNull
              ?.title ??
          'Feed';
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
            cached: true,
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

        // Full content (available)
        if (contentStatus == _ContentStatus.available &&
            currentArticle.fullContent != null &&
            currentArticle.fullContent!.isNotEmpty) ...[
          ...renderParagraphs(
            currentArticle.fullContent!,
            theme.textTheme.bodyMedium?.copyWith(
                  color: BmoColors.textPrimary,
                  height: 1.6,
                ) ??
                TextStyle(
                  color: BmoColors.textPrimary,
                  height: 1.6,
                ),
          ),
        ],

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
      ],
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
// Summary block (BMO AI)
// ============================================================

class _SummaryBlock extends StatelessWidget {
  final String text;
  final bool cached;
  final ThemeData theme;

  const _SummaryBlock({
    required this.text,
    required this.cached,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
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
              if (cached) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: BmoColors.accentYellow.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'cache',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: BmoColors.accentYellow,
                      fontSize: 9,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: BmoColors.textPrimary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
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
