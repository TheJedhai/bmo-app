import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/bmo_theme.dart';
import '../../data/models/feed.dart';
import '../../data/rss_client.dart';
import '../../data/rss_providers.dart';

class FeedFormModal extends ConsumerStatefulWidget {
  final Feed? feed;

  const FeedFormModal({super.key, this.feed});

  bool get isEditing => feed != null;

  @override
  ConsumerState<FeedFormModal> createState() => _FeedFormModalState();
}

class _FeedFormModalState extends ConsumerState<FeedFormModal> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _urlCtrl;
  late final TextEditingController _intervalCtrl;
  bool _showAdvanced = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final feed = widget.feed;
    _titleCtrl = TextEditingController(text: feed?.title ?? '');
    _urlCtrl = TextEditingController(text: feed?.url ?? '');
    _intervalCtrl = TextEditingController(
      text: (feed?.fetchIntervalMinutes ?? 60).toString(),
    );
    // Show advanced section if editing a feed with non-default interval
    if (feed != null && feed.fetchIntervalMinutes != 60) {
      _showAdvanced = true;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _urlCtrl.dispose();
    _intervalCtrl.dispose();
    super.dispose();
  }

  bool get _canSave {
    return _urlCtrl.text.trim().isNotEmpty;
  }

  Future<void> _save() async {
    if (!_canSave || _saving) return;

    setState(() => _saving = true);

    final feeds = ref.read(feedsProvider.notifier);
    final title = _titleCtrl.text.trim().isEmpty
        ? null
        : _titleCtrl.text.trim();
    final url = _urlCtrl.text.trim();
    final interval = int.tryParse(_intervalCtrl.text.trim()) ?? 60;

    try {
      if (widget.isEditing) {
        final feed = widget.feed!;
        await feeds.edit(
          feed.id,
          title: title,
          url: url,
          fetchIntervalMinutes: _showAdvanced ? interval : null,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Feed atualizado')),
        );
      } else {
        final created = await feeds.create(
          title: title ?? url,
          url: url,
          fetchIntervalMinutes: _showAdvanced ? interval : null,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Feed adicionado')),
        );

        // Refresh immediately to pull articles right away
        await feeds.refreshFeed(created.id);
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on RssApiException catch (e) {
      setState(() => _saving = false);
      if (!mounted) return;
      final message = switch (e.errorCode) {
        'feed_url_exists' => 'Essa fonte já está cadastrada',
        _ => e.message,
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      setState(() => _saving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Dialog(
      backgroundColor: BmoColors.screenBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: BmoColors.bodyGreen, width: 2),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isMobile ? double.infinity : 480,
          maxHeight: MediaQuery.of(context).size.height * 0.80,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Text(
                    widget.isEditing ? 'Editar fonte' : 'Nova fonte',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: 12,
                      color: BmoColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            // Scrollable body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Title
                    TextField(
                      controller: _titleCtrl,
                      autofocus: !widget.isEditing,
                      style: theme.textTheme.bodyMedium,
                      decoration: const InputDecoration(
                        hintText: 'Título (opcional — usamos a URL se vazio)',
                        hintStyle: TextStyle(color: BmoColors.textMuted),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    // URL (required)
                    TextField(
                      controller: _urlCtrl,
                      style: theme.textTheme.bodyMedium,
                      decoration: const InputDecoration(
                        hintText: 'URL do feed (RSS/Atom)',
                        hintStyle: TextStyle(color: BmoColors.textMuted),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),

                    // Advanced toggle
                    GestureDetector(
                      onTap: () =>
                          setState(() => _showAdvanced = !_showAdvanced),
                      child: Row(
                        children: [
                          Icon(
                            _showAdvanced
                                ? Icons.expand_less
                                : Icons.expand_more,
                            size: 16,
                            color: BmoColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Avançado',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: BmoColors.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_showAdvanced) ...[
                      const SizedBox(height: 10),
                      // Fetch interval
                      _Label(text: 'Intervalo de fetch (minutos)', theme: theme),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _intervalCtrl,
                        keyboardType: TextInputType.number,
                        style: theme.textTheme.bodySmall,
                        decoration: const InputDecoration(
                          hintText: '60',
                          hintStyle: TextStyle(color: BmoColors.textMuted),
                          isDense: true,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            // Bottom bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                    child: Text(
                      'Cancelar',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: BmoColors.textSecondary,
                      ),
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _canSave && !_saving ? _save : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: BmoColors.accentGreen,
                      foregroundColor: BmoColors.screenBg,
                      disabledBackgroundColor: BmoColors.textMuted,
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: BmoColors.screenBg,
                            ),
                          )
                        : const Text('Salvar'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Shared small widget
// ============================================================

class _Label extends StatelessWidget {
  final String text;
  final ThemeData theme;

  const _Label({required this.text, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: theme.textTheme.labelMedium?.copyWith(
        color: BmoColors.textMuted,
        fontSize: 11,
      ),
    );
  }
}
