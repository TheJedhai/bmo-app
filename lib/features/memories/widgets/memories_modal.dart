import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/bmo_theme.dart';
import '../data/memory_model.dart';
import '../providers/memories_provider.dart';

const _kMobileBreakpoint = 600.0;

void showMemoriesModal(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (_) => const _MemoriesModal(),
  );
}

class _MemoriesModal extends ConsumerStatefulWidget {
  const _MemoriesModal();

  @override
  ConsumerState<_MemoriesModal> createState() => _MemoriesModalState();
}

class _MemoriesModalState extends ConsumerState<_MemoriesModal> {
  final _searchController = TextEditingController();
  String _query = '';

  final _createController = TextEditingController();
  bool _creating = false;
  String? _createError;

  int? _editingId;
  TextEditingController? _editController;
  FocusNode? _editFocusNode;
  int? _savingId;
  String? _editError;

  @override
  void dispose() {
    _searchController.dispose();
    _createController.dispose();
    _editController?.dispose();
    _editFocusNode?.dispose();
    super.dispose();
  }

  List<Memory> _filter(List<Memory> all) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where((m) => m.content.toLowerCase().contains(q))
        .toList(growable: false);
  }

  void _startEditing(Memory memory) {
    _cancelEditing();
    _editingId = memory.id;
    _editController = TextEditingController(text: memory.content);
    _editFocusNode = FocusNode();
    _editError = null;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _editFocusNode?.requestFocus();
    });
  }

  void _cancelEditing() {
    if (_editingId == null) return;
    _editController?.dispose();
    _editFocusNode?.dispose();
    _editingId = null;
    _editController = null;
    _editFocusNode = null;
    _editError = null;
    _savingId = null;
    setState(() {});
  }

  Future<void> _saveEditing() async {
    if (_editingId == null || _editController == null) return;
    final content = _editController!.text.trim();
    if (content.isEmpty) return;

    setState(() {
      _savingId = _editingId;
      _editError = null;
    });

    try {
      await ref
          .read(memoriesProvider.notifier)
          .updateMemory(_editingId!, content);
      _cancelEditing();
    } catch (e) {
      setState(() {
        _editError = e.toString();
        _savingId = null;
      });
    }
  }

  Future<void> _createMemory() async {
    final content = _createController.text.trim();
    if (content.isEmpty) return;

    setState(() {
      _creating = true;
      _createError = null;
    });

    try {
      await ref.read(memoriesProvider.notifier).createMemory(content);
      _createController.clear();
      setState(() => _creating = false);
    } catch (e) {
      setState(() {
        _createError = e.toString();
        _creating = false;
      });
    }
  }

  Future<void> _confirmAndDelete(Memory memory) async {
    final preview = memory.content.length > 40
        ? '${memory.content.substring(0, 40)}...'
        : memory.content;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BmoColors.screenBgElevated,
        title: const Text('Apagar memória?'),
        content: Text("Apagar '$preview'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(memoriesProvider.notifier).deleteMemory(memory.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('falha ao apagar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < _kMobileBreakpoint;
    final memoriesAsync = ref.watch(memoriesProvider);

    return Dialog(
      backgroundColor: BmoColors.screenBgElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: BmoColors.bodyGreen, width: 2),
      ),
      insetPadding: isMobile
          ? const EdgeInsets.all(8)
          : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isMobile ? double.infinity : 650,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Header(onClose: () => Navigator.of(context).pop()),
            _SearchField(
              controller: _searchController,
              hasText: _query.isNotEmpty,
              onChanged: (v) => setState(() => _query = v),
            ),
            _CreateInput(
              controller: _createController,
              creating: _creating,
              error: _createError,
              onSubmit: _createMemory,
            ),
            Flexible(
              child: memoriesAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => _ErrorState(
                  error: e,
                  onRetry: () => ref.invalidate(memoriesProvider),
                ),
                data: (memories) {
                  final filtered = _filter(memories);
                  if (filtered.isEmpty) {
                    return _EmptyState(
                      hasSearch: _query.isNotEmpty,
                      theme: theme,
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => _MemoryListItem(
                      memory: filtered[i],
                      isEditing: _editingId == filtered[i].id,
                      saving: _savingId == filtered[i].id,
                      editError: _editingId == filtered[i].id
                          ? _editError
                          : null,
                      editController:
                          _editingId == filtered[i].id ? _editController : null,
                      editFocusNode:
                          _editingId == filtered[i].id ? _editFocusNode : null,
                      onTap: () => _startEditing(filtered[i]),
                      onSave: _saveEditing,
                      onCancelEdit: _cancelEditing,
                      onEdit: () => _startEditing(filtered[i]),
                      onDelete: () => _confirmAndDelete(filtered[i]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onClose;

  const _Header({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
      child: Row(
        children: [
          Text(
            'Memórias',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.close, color: BmoColors.textSecondary),
            tooltip: 'Fechar',
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final bool hasText;
  final ValueChanged<String> onChanged;

  const _SearchField({
    required this.controller,
    required this.hasText,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: BmoColors.textPrimary,
            ),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'buscar...',
          hintStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: BmoColors.textMuted,
              ),
          prefixIcon: Icon(
            Icons.search,
            size: 16,
            color: BmoColors.textMuted,
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 32,
            minHeight: 32,
          ),
          suffixIcon: !hasText
              ? null
              : IconButton(
                  iconSize: 16,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  tooltip: 'limpar',
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                  icon: Icon(
                    Icons.close,
                    color: BmoColors.textMuted,
                  ),
                ),
          filled: true,
          fillColor: BmoColors.screenBg,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: BmoColors.textMuted.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(
              color: BmoColors.accentGreen,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _CreateInput extends StatelessWidget {
  final TextEditingController controller;
  final bool creating;
  final String? error;
  final VoidCallback onSubmit;

  const _CreateInput({
    required this.controller,
    required this.creating,
    required this.error,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  onSubmitted: (_) => onSubmit(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: BmoColors.textPrimary,
                      ),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Nova memória...',
                    hintStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: BmoColors.textMuted,
                        ),
                    filled: true,
                    fillColor: BmoColors.screenBg,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: BmoColors.textMuted.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: BmoColors.accentGreen,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 40,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: BmoColors.accentGreen,
                    foregroundColor: const Color(0xFF0F1115),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onPressed: creating ? null : onSubmit,
                  child: creating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          'Adicionar',
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(
                                color: const Color(0xFF0F1115),
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                ),
              ),
            ],
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                error!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.redAccent,
                    ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MemoryListItem extends StatelessWidget {
  final Memory memory;
  final bool isEditing;
  final bool saving;
  final String? editError;
  final TextEditingController? editController;
  final FocusNode? editFocusNode;
  final VoidCallback onTap;
  final VoidCallback onSave;
  final VoidCallback onCancelEdit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MemoryListItem({
    required this.memory,
    required this.isEditing,
    required this.saving,
    required this.editError,
    required this.editController,
    required this.editFocusNode,
    required this.onTap,
    required this.onSave,
    required this.onCancelEdit,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sourceIcon = memory.source == 'agent'
        ? Icons.smart_toy_outlined
        : Icons.person_outline;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: BmoColors.screenBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: isEditing ? _buildEditing(theme) : _buildDisplay(theme, sourceIcon),
          ),
          if (isEditing && editError != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Text(
                editError!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.redAccent,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDisplay(ThemeData theme, IconData sourceIcon) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                sourceIcon,
                size: 18,
                color: memory.source == 'agent'
                    ? BmoColors.accentYellow
                    : BmoColors.textSecondary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                memory.content,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: BmoColors.textPrimary,
                ),
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert,
                size: 18,
                color: BmoColors.textMuted,
              ),
              color: BmoColors.screenBgElevated,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 28,
                minHeight: 28,
              ),
              onSelected: (value) {
                if (value == 'edit') {
                  onEdit();
                } else if (value == 'delete') {
                  onDelete();
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Text('Editar'),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Apagar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditing(ThemeData theme) {
    return TapRegion(
      onTapOutside: (_) => onCancelEdit(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Icon(
                    memory.source == 'agent'
                        ? Icons.smart_toy_outlined
                        : Icons.person_outline,
                    size: 18,
                    color: memory.source == 'agent'
                        ? BmoColors.accentYellow
                        : BmoColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Focus(
                    onKeyEvent: (node, event) {
                      if (event is KeyDownEvent) {
                        if (event.logicalKey == LogicalKeyboardKey.enter) {
                          final shiftPressed = HardwareKeyboard.instance
                              .logicalKeysPressed
                              .any((k) =>
                                  k == LogicalKeyboardKey.shiftLeft ||
                                  k == LogicalKeyboardKey.shiftRight);
                          if (!shiftPressed) {
                            onSave();
                            return KeyEventResult.handled;
                          }
                        }
                        if (event.logicalKey == LogicalKeyboardKey.escape) {
                          onCancelEdit();
                          return KeyEventResult.handled;
                        }
                      }
                      return KeyEventResult.ignored;
                    },
                    child: TextField(
                      controller: editController,
                      focusNode: editFocusNode,
                      maxLines: null,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: BmoColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 6,
                          horizontal: 8,
                        ),
                        filled: true,
                        fillColor: BmoColors.screenBgElevated,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(
                            color: BmoColors.accentGreen.withValues(alpha: 0.5),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(
                            color: BmoColors.accentGreen,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  tooltip: 'Cancelar',
                  onPressed: onCancelEdit,
                  icon: Icon(Icons.close, color: BmoColors.textSecondary),
                ),
                const SizedBox(width: 4),
                IconButton(
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  tooltip: 'Salvar',
                  onPressed: saving ? null : onSave,
                  icon: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.check, color: BmoColors.accentGreen),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasSearch;
  final ThemeData theme;

  const _EmptyState({required this.hasSearch, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Text(
          hasSearch ? 'Nenhuma memória encontrada' : 'Nenhuma memória ainda',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: BmoColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.redAccent, size: 32),
            const SizedBox(height: 8),
            Text(
              'falha ao carregar',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.redAccent,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: BmoColors.textMuted,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onRetry,
              child: const Text('tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}
