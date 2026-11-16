import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bmo_app/core/events/events_provider.dart';
import 'package:bmo_app/core/theme/bmo_theme.dart';
import 'package:bmo_app/features/memories/data/memories_client.dart';
import 'package:bmo_app/features/memories/providers/memories_provider.dart';
import 'package:bmo_app/features/memories/widgets/memory_scope_chip.dart';
import 'package:bmo_app/features/rich_blocks/data/bmo_rich_block.dart';
import 'package:bmo_app/features/rich_blocks/widgets/bmo_clamped_text.dart';

/// Card do bloco rico `memory_saved`.
///
/// Payload `{memory_id, content, scope: "personal"|"house"}`. O conteúdo pode
/// mudar depois (`rich.update` com `{content}`) e a memória pode ser apagada
/// por outro cliente (`{status: "undone"}`). Como o EventBus é efêmero, o card
/// re-sincroniza por REST no mount e no reconnect do SSE — 404 = desfeita.
class BmoRichMemoryCard extends ConsumerStatefulWidget {
  final BmoRichBlock block;

  const BmoRichMemoryCard({super.key, required this.block});

  @override
  ConsumerState<BmoRichMemoryCard> createState() => _BmoRichMemoryCardState();
}

class _BmoRichMemoryCardState extends ConsumerState<BmoRichMemoryCard> {
  late String _content = _payloadContent;
  late bool _personal = _payloadPersonal;

  bool _undone = false;
  bool _busy = false;
  String? _error;

  int get _memoryId {
    final v = widget.block.payload['memory_id'];
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    // Fallback pelo contrato do block_id: `memory-{id}`.
    return int.tryParse(widget.block.blockId.replaceFirst('memory-', '')) ?? 0;
  }

  String get _payloadContent {
    final v = widget.block.payload['content'];
    return v is String ? v : '';
  }

  bool get _payloadPersonal => widget.block.payload['scope'] == 'personal';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _memoryId > 0) _resync();
    });
  }

  Future<void> _resync() async {
    try {
      final memory =
          await ref.read(memoriesClientProvider).get(_memoryId);
      if (!mounted) return;
      setState(() {
        _content = memory.content;
        _personal = memory.isPersonal;
        _undone = false;
      });
    } on MemoriesApiException catch (e) {
      if (!mounted) return;
      // 404 = memória apagada em outro cliente.
      if (e.statusCode == 404) setState(() => _undone = true);
    } catch (_) {
      // Best-effort: sem rede o card fica com o payload do bloco.
    }
  }

  void _applyPatch(Map<String, dynamic> patch) {
    if (!mounted) return;
    final content = patch['content'];
    final status = patch['status'];
    final scope = patch['scope'];
    setState(() {
      if (content is String) _content = content;
      if (scope is String) _personal = scope == 'personal';
      if (status == 'undone') _undone = true;
    });
  }

  Future<void> _undo() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(memoriesClientProvider).delete(_memoryId);
      // Aplicar local evita o botão travado se o SSE cair no meio.
      if (mounted) setState(() => _undone = true);
    } on MemoriesApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 404) {
        setState(() => _undone = true);
      } else {
        setState(() => _error = 'falha ao desfazer: ${e.message}');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'falha ao desfazer: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Patches de rich.update deste bloco.
    ref.listen<AsyncValue<Map<String, dynamic>>>(eventsStreamProvider, (
      previous,
      next,
    ) {
      final event = next.valueOrNull;
      if (event == null) return;
      if (event['type'] != 'rich.update') return;
      if (event['block_id'] != widget.block.blockId) return;
      final patch = event['patch'];
      if (patch is Map) _applyPatch(Map<String, dynamic>.from(patch));
    });

    // Re-sync em cada reconexão do SSE.
    ref.listen<int>(sseGenerationProvider, (previous, next) {
      if (previous != next && _memoryId > 0) _resync();
    });

    final color = _undone ? BmoColors.textMuted : BmoColors.accentGreen;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: BmoColors.screenBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  _undone ? Icons.delete_outline : Icons.psychology_outlined,
                  size: 16,
                  color: color,
                ),
                const SizedBox(width: 8),
                Text(
                  _undone ? 'Desfeita' : 'Memória salva',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (!_undone) MemoryScopeChip(personal: _personal),
              ],
            ),
            const SizedBox(height: 6),
            BmoClampedText(
              _content,
              maxLines: 4,
              style: theme.textTheme.bodySmall?.copyWith(
                color: _undone ? BmoColors.textMuted : BmoColors.textPrimary,
                decoration: _undone ? TextDecoration.lineThrough : null,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 6),
              BmoClampedText(
                _error!,
                maxLines: 2,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: BmoColors.accentRed),
              ),
            ],
            if (!_undone && widget.block.mutable && _memoryId > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton(
                    onPressed: _busy ? null : _undo,
                    style: TextButton.styleFrom(
                      foregroundColor: BmoColors.accentRed,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Desfazer'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
