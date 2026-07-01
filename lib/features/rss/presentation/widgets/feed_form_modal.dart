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
  late final TextEditingController _tagInputCtrl;
  late final FocusNode _tagInputFocus;
  String _tagFilterMode = 'off';
  List<String> _tagFilter = [];
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
    _tagInputCtrl = TextEditingController();
    _tagInputFocus = FocusNode();
    if (feed != null) {
      _tagFilterMode = feed.tagFilterMode;
      _tagFilter = List<String>.from(feed.tagFilter);
    }
    // Show advanced section if editing a feed with non-default settings
    if (feed != null) {
      if (feed.fetchIntervalMinutes != 60) _showAdvanced = true;
      if (feed.tagFilterMode != 'off' || feed.tagFilter.isNotEmpty) {
        _showAdvanced = true;
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _urlCtrl.dispose();
    _intervalCtrl.dispose();
    _tagInputCtrl.dispose();
    _tagInputFocus.dispose();
    super.dispose();
  }

  bool get _canSave {
    return _urlCtrl.text.trim().isNotEmpty;
  }

  String get _tagFilterHelpText {
    return switch (_tagFilterMode) {
      'allow' => 'Traz apenas artigos que tenham ao menos uma das tags abaixo',
      'block' => 'Descarta artigos que tenham qualquer uma das tags abaixo',
      _ => 'Nenhum filtro de tags aplicado',
    };
  }

  void _addTag() {
    final raw = _tagInputCtrl.text.trim();
    if (raw.isEmpty) return;

    // Split by comma and process each tag
    final tags = raw
        .split(',')
        .map((t) => t.trim().toLowerCase())
        .where((t) => t.isNotEmpty);

    var added = false;
    for (final tag in tags) {
      if (!_tagFilter.contains(tag)) {
        _tagFilter = [..._tagFilter, tag];
        added = true;
      }
    }

    if (added) {
      _tagInputCtrl.clear();
      setState(() {});
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tagFilter = _tagFilter.where((t) => t != tag).toList();
    });
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
          tagFilterMode: _tagFilterMode,
          tagFilter: _tagFilterMode == 'off' ? const [] : _tagFilter,
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
          tagFilterMode: _tagFilterMode,
          tagFilter: _tagFilterMode == 'off' ? const [] : _tagFilter,
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
                      const SizedBox(height: 14),
                      // Tag filter mode
                      _Label(text: 'Filtro de tags', theme: theme),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          for (final mode in const [
                            ('off', 'Desligado'),
                            ('allow', 'Permitir'),
                            ('block', 'Bloquear'),
                          ])
                            ChoiceChip(
                              label: Text(
                                mode.$2,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: _tagFilterMode == mode.$1
                                      ? BmoColors.accentGreen
                                      : BmoColors.textSecondary,
                                ),
                              ),
                              selected: _tagFilterMode == mode.$1,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() => _tagFilterMode = mode.$1);
                                }
                              },
                              selectedColor:
                                  BmoColors.accentGreen.withValues(alpha: 0.15),
                              backgroundColor: BmoColors.screenBgElevated,
                              side: BorderSide(
                                color: _tagFilterMode == mode.$1
                                    ? BmoColors.accentGreen
                                    : BmoColors.textMuted.withValues(alpha: 0.3),
                              ),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _tagFilterHelpText,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: BmoColors.textMuted,
                          fontSize: 10,
                        ),
                      ),
                      if (_tagFilterMode != 'off') ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: _tagInputCtrl,
                          focusNode: _tagInputFocus,
                          style: theme.textTheme.bodySmall,
                          decoration: const InputDecoration(
                            hintText: 'Digite uma tag e pressione Enter',
                            hintStyle: TextStyle(
                              color: BmoColors.textMuted,
                              fontSize: 12,
                            ),
                            isDense: true,
                          ),
                          onSubmitted: (_) => _addTag(),
                          onChanged: (_) => setState(() {}),
                        ),
                        if (_tagFilter.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: _tagFilter.map((tag) {
                              return InputChip(
                                label: Text(
                                  tag,
                                  style: const TextStyle(fontSize: 11),
                                ),
                                onDeleted: () => _removeTag(tag),
                                backgroundColor: BmoColors.screenBgElevated,
                                side: BorderSide(
                                  color: BmoColors.accentGreen.withValues(alpha: 0.3),
                                ),
                                labelStyle: const TextStyle(
                                  color: BmoColors.textPrimary,
                                  fontSize: 11,
                                ),
                                deleteIconColor: BmoColors.textMuted,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 0,
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
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
