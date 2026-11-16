import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/bmo_theme.dart';
import '../../../core/widgets/bmo_back_button.dart';
import '../data/memory_model.dart';
import '../providers/memories_provider.dart';
import '../widgets/memory_scope_chip.dart';

/// Tela de Memórias (`/memorias`).
///
/// Lista o que o BMO sabe (casa + pessoal), com busca no servidor
/// (`/memories/search`), filtro de escopo, criação/edição com escopo e
/// apagar. Os eventos SSE `memory.*` invalidam [memoriesProvider], então a
/// lista se atualiza sozinha quando outro cliente mexe.
class MemoriesScreen extends ConsumerStatefulWidget {
  const MemoriesScreen({super.key});

  @override
  ConsumerState<MemoriesScreen> createState() => _MemoriesScreenState();
}

class _MemoriesScreenState extends ConsumerState<MemoriesScreen> {
  static const _kDebounce = Duration(milliseconds: 300);

  final _searchController = TextEditingController();
  String _query = '';
  Timer? _debounce;

  final _createController = TextEditingController();
  bool _createPersonal = false;
  bool _creating = false;
  String? _createError;

  int? _editingId;
  TextEditingController? _editController;
  FocusNode? _editFocusNode;
  bool _editPersonal = false;
  int? _savingId;
  String? _editError;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _createController.dispose();
    _editController?.dispose();
    _editFocusNode?.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(_kDebounce, () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    setState(() => _query = '');
  }

  void _startEditing(Memory memory) {
    _cancelEditing();
    setState(() {
      _editingId = memory.id;
      _editController = TextEditingController(text: memory.content);
      _editFocusNode = FocusNode();
      _editPersonal = memory.isPersonal;
      _editError = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _editFocusNode?.requestFocus();
    });
  }

  void _cancelEditing() {
    if (_editingId == null) return;
    _editController?.dispose();
    _editFocusNode?.dispose();
    setState(() {
      _editingId = null;
      _editController = null;
      _editFocusNode = null;
      _editError = null;
      _savingId = null;
    });
  }

  Future<void> _saveEditing() async {
    final id = _editingId;
    final controller = _editController;
    if (id == null || controller == null) return;
    final content = controller.text.trim();
    if (content.isEmpty) return;

    setState(() {
      _savingId = id;
      _editError = null;
    });

    try {
      await ref.read(memoriesProvider.notifier).updateMemory(
            id,
            content: content,
            personal: _editPersonal,
          );
      _cancelEditing();
    } catch (e) {
      if (mounted) {
        setState(() {
          _editError = e.toString();
          _savingId = null;
        });
      }
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
      await ref
          .read(memoriesProvider.notifier)
          .createMemory(content, personal: _createPersonal);
      if (mounted) {
        _createController.clear();
        setState(() => _creating = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _createError = e.toString();
          _creating = false;
        });
      }
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('falha ao apagar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scope = ref.watch(memoriesScopeModeProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: BmoColors.screenBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const BmoBackButton(),
        title: Text('Memórias', style: theme.textTheme.headlineSmall),
      ),
      body: Column(
        children: [
          _SearchField(
            controller: _searchController,
            hasText: _query.isNotEmpty,
            onChanged: _onSearchChanged,
            onClear: _clearSearch,
          ),
          _CreateInput(
            controller: _createController,
            personal: _createPersonal,
            creating: _creating,
            error: _createError,
            onScopeChanged: (v) => setState(() => _createPersonal = v),
            onSubmit: _createMemory,
          ),
          _ScopeFilter(
            selected: scope,
            onChanged: (s) =>
                ref.read(memoriesScopeModeProvider.notifier).set(s),
          ),
          Expanded(
            child: _query.isEmpty
                ? _MemoryList(
                    memoriesAsync: ref.watch(memoriesProvider),
                    onRetry: () => ref.invalidate(memoriesProvider),
                    editingId: _editingId,
                    savingId: _savingId,
                    editError: _editError,
                    editController: _editController,
                    editFocusNode: _editFocusNode,
                    editPersonal: _editPersonal,
                    onEditPersonalChanged: (v) =>
                        setState(() => _editPersonal = v),
                    onStartEdit: _startEditing,
                    onSave: _saveEditing,
                    onCancelEdit: _cancelEditing,
                    onDelete: _confirmAndDelete,
                    emptyMessage: 'Nenhuma memória ainda',
                  )
                : _MemoryList(
                    memoriesAsync: ref.watch(memorySearchProvider(_query)),
                    onRetry: () => ref.invalidate(memorySearchProvider(_query)),
                    editingId: _editingId,
                    savingId: _savingId,
                    editError: _editError,
                    editController: _editController,
                    editFocusNode: _editFocusNode,
                    editPersonal: _editPersonal,
                    onEditPersonalChanged: (v) =>
                        setState(() => _editPersonal = v),
                    onStartEdit: _startEditing,
                    onSave: _saveEditing,
                    onCancelEdit: _cancelEditing,
                    onDelete: _confirmAndDelete,
                    emptyMessage: 'Nenhuma memória encontrada',
                  ),
          ),
        ],
      ),
    );
  }
}

/// Lista pronta para os dois estados (normal e busca).
class _MemoryList extends StatelessWidget {
  final AsyncValue<List<Memory>> memoriesAsync;
  final VoidCallback onRetry;
  final int? editingId;
  final int? savingId;
  final String? editError;
  final TextEditingController? editController;
  final FocusNode? editFocusNode;
  final bool editPersonal;
  final ValueChanged<bool> onEditPersonalChanged;
  final ValueChanged<Memory> onStartEdit;
  final VoidCallback onSave;
  final VoidCallback onCancelEdit;
  final ValueChanged<Memory> onDelete;
  final String emptyMessage;

  const _MemoryList({
    required this.memoriesAsync,
    required this.onRetry,
    required this.editingId,
    required this.savingId,
    required this.editError,
    required this.editController,
    required this.editFocusNode,
    required this.editPersonal,
    required this.onEditPersonalChanged,
    required this.onStartEdit,
    required this.onSave,
    required this.onCancelEdit,
    required this.onDelete,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    return memoriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorState(error: e, onRetry: onRetry),
      data: (memories) {
        if (memories.isEmpty) return _EmptyState(message: emptyMessage);
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 16),
          itemCount: memories.length,
          itemBuilder: (_, i) {
            final memory = memories[i];
            return MemoryListItem(
              memory: memory,
              isEditing: editingId == memory.id,
              saving: savingId == memory.id,
              editError: editingId == memory.id ? editError : null,
              editController: editingId == memory.id ? editController : null,
              editFocusNode: editingId == memory.id ? editFocusNode : null,
              editPersonal: editPersonal,
              onEditPersonalChanged: onEditPersonalChanged,
              onTap: () => onStartEdit(memory),
              onSave: onSave,
              onCancelEdit: onCancelEdit,
              onEdit: () => onStartEdit(memory),
              onDelete: () => onDelete(memory),
            );
          },
        );
      },
    );
  }
}

/// Seletor de escopo de duas opções (criação/edição).
class MemoryScopeToggle extends StatelessWidget {
  final bool personal;
  final ValueChanged<bool> onChanged;

  const MemoryScopeToggle({
    super.key,
    required this.personal,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _option('Pessoal', true),
        const SizedBox(width: 4),
        _option('Da casa', false),
      ],
    );
  }

  Widget _option(String label, bool value) {
    final selected = personal == value;
    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: selected
              ? BmoColors.accentGreen.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? BmoColors.accentGreen
                : BmoColors.textMuted.withValues(alpha: 0.4),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            color: BmoColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _ScopeFilter extends StatelessWidget {
  final MemoryScope selected;
  final ValueChanged<MemoryScope> onChanged;

  const _ScopeFilter({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Row(
        children: [
          for (final scope in MemoryScope.values) ...[
            ChoiceChip(
              label: Text(scope.label),
              selected: selected == scope,
              onSelected: (_) => onChanged(scope),
              labelStyle: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: BmoColors.textPrimary,
              ),
              backgroundColor: BmoColors.screenBg,
              selectedColor: BmoColors.accentGreen.withValues(alpha: 0.2),
              side: BorderSide(
                color: selected == scope
                    ? BmoColors.accentGreen
                    : BmoColors.textMuted.withValues(alpha: 0.3),
              ),
              visualDensity: VisualDensity.compact,
              showCheckmark: false,
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final bool hasText;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchField({
    required this.controller,
    required this.hasText,
    required this.onChanged,
    required this.onClear,
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
          prefixIcon: const Icon(Icons.search, size: 16, color: BmoColors.textMuted),
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
                  onPressed: onClear,
                  icon: const Icon(Icons.close, color: BmoColors.textMuted),
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
  final bool personal;
  final bool creating;
  final String? error;
  final ValueChanged<bool> onScopeChanged;
  final VoidCallback onSubmit;

  const _CreateInput({
    required this.controller,
    required this.personal,
    required this.creating,
    required this.error,
    required this.onScopeChanged,
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
          const SizedBox(height: 6),
          MemoryScopeToggle(personal: personal, onChanged: onScopeChanged),
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

class MemoryListItem extends StatelessWidget {
  final Memory memory;
  final bool isEditing;
  final bool saving;
  final String? editError;
  final TextEditingController? editController;
  final FocusNode? editFocusNode;
  final bool editPersonal;
  final ValueChanged<bool> onEditPersonalChanged;
  final VoidCallback onTap;
  final VoidCallback onSave;
  final VoidCallback onCancelEdit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const MemoryListItem({
    super.key,
    required this.memory,
    required this.isEditing,
    required this.saving,
    required this.editError,
    required this.editController,
    required this.editFocusNode,
    required this.editPersonal,
    required this.onEditPersonalChanged,
    required this.onTap,
    required this.onSave,
    required this.onCancelEdit,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
            child: isEditing ? _buildEditing(theme) : _buildDisplay(theme),
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

  IconData get _sourceIcon =>
      memory.source == 'agent' ? Icons.smart_toy_outlined : Icons.person_outline;

  Color get _sourceColor => memory.source == 'agent'
      ? BmoColors.accentYellow
      : BmoColors.textSecondary;

  Widget _buildDisplay(ThemeData theme) {
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
              child: Icon(_sourceIcon, size: 18, color: _sourceColor),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    memory.content,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: BmoColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  MemoryScopeChip(personal: memory.isPersonal),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_vert,
                size: 18,
                color: BmoColors.textMuted,
              ),
              color: BmoColors.screenBgElevated,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              onSelected: (value) {
                if (value == 'edit') {
                  onEdit();
                } else if (value == 'delete') {
                  onDelete();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Editar')),
                PopupMenuItem(value: 'delete', child: Text('Apagar')),
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
                  child: Icon(_sourceIcon, size: 18, color: _sourceColor),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Focus(
                    onKeyEvent: (node, event) {
                      if (event is KeyDownEvent) {
                        if (event.logicalKey == LogicalKeyboardKey.enter) {
                          final shiftPressed = HardwareKeyboard
                              .instance.logicalKeysPressed
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
              children: [
                MemoryScopeToggle(
                  personal: editPersonal,
                  onChanged: onEditPersonalChanged,
                ),
                const Spacer(),
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
                  icon: const Icon(Icons.close, color: BmoColors.textSecondary),
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
                      : const Icon(Icons.check, color: BmoColors.accentGreen),
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
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 32),
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
