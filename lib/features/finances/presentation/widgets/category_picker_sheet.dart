import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/bmo_theme.dart';
import '../../data/categorization_providers.dart';
import '../../data/models/category.dart';
import '../category_management_screen.dart';

/// Bottom sheet: seletor de categoria agrupado por kind, com busca.
///
/// Retorna a [Category] selecionada via Navigator.pop, ou null se cancelar.
class CategoryPickerSheet extends ConsumerStatefulWidget {
  const CategoryPickerSheet({super.key});

  @override
  ConsumerState<CategoryPickerSheet> createState() =>
      _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends ConsumerState<CategoryPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _createAndSelect(BuildContext context) async {
    final name = _query.trim();
    if (name.isEmpty) return;

    CategoryKind? kind = CategoryKind.expense;

    final shouldCreate = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: BmoColors.screenBgElevated,
          title: const Text('Nova categoria',
              style: TextStyle(
                fontFamily: 'Inter',
                color: BmoColors.textPrimary,
              )),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Nome: "$name"',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: BmoColors.textPrimary,
                  )),
              const SizedBox(height: 12),
              DropdownButtonFormField<CategoryKind>(
                initialValue: kind,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: BmoColors.textPrimary,
                ),
                dropdownColor: BmoColors.screenBgElevated,
                decoration: InputDecoration(
                  labelText: 'Tipo',
                  labelStyle: const TextStyle(color: BmoColors.textMuted),
                  filled: true,
                  fillColor: BmoColors.screenBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: [
                  CategoryKind.expense,
                  CategoryKind.income,
                  CategoryKind.internal,
                ].map((k) {
                  return DropdownMenuItem(
                    value: k,
                    child: Text(k.labelPt,
                        style: const TextStyle(fontFamily: 'Inter')),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v != null) setDialogState(() => kind = v);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: BmoColors.textMuted,
                  )),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Criar',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: BmoColors.accentGreen,
                  )),
            ),
          ],
        ),
      ),
    );

    if (shouldCreate != true) return;

    try {
      final notifier = ref.read(categoriesProvider.notifier);
      final cat = await notifier.create(name: name, kind: kind!.name);
      if (mounted && context.mounted) {
        Navigator.of(context).pop(cat);
      }
    } catch (e) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: BmoColors.screenBgElevated,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: BmoColors.screenBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // Drag handle
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: BmoColors.textMuted.withAlpha(100),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Title
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Selecionar categoria',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: BmoColors.textPrimary,
                  ),
                ),
              ),
              // Search + manage
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 36,
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            color: BmoColors.textPrimary,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Buscar categoria...',
                            hintStyle: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              color: BmoColors.textMuted,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            filled: true,
                            fillColor: BmoColors.screenBgElevated,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            prefixIcon: const Icon(Icons.search,
                                size: 18, color: BmoColors.textMuted),
                          ),
                          onChanged: (_) =>
                              setState(() => _query = _searchController.text),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _ManageButton(onCreated: () {
                      // Refresh categories after management screen returns
                      ref.invalidate(categoriesProvider);
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Divider(color: BmoColors.screenBgElevated, height: 1),
              // List
              Expanded(
                child: categoriesAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                        color: BmoColors.accentGreen),
                  ),
                  error: (e, _) => Center(
                    child: Text(
                      'Erro ao carregar categorias.',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: BmoColors.textSecondary,
                      ),
                    ),
                  ),
                  data: (categories) {
                    final filtered = _query.isEmpty
                        ? categories
                        : categories
                            .where((c) => c.name
                                .toLowerCase()
                                .contains(_query.toLowerCase()))
                            .toList();

                    if (filtered.isEmpty) {
                      return ListView(
                        controller: scrollController,
                        children: [
                          const SizedBox(height: 32),
                          Text(
                            _query.isEmpty
                                ? 'Nenhuma categoria cadastrada.'
                                : 'Nenhuma categoria para "$_query".',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              color: BmoColors.textMuted,
                            ),
                          ),
                          if (_query.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Center(
                              child: TextButton.icon(
                                onPressed: () => _createAndSelect(context),
                                icon: const Icon(Icons.add,
                                    size: 16, color: BmoColors.accentGreen),
                                label: Text(
                                  'Criar "$_query"',
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 13,
                                    color: BmoColors.accentGreen,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      );
                    }

                    // Group by kind
                    final kinds = <CategoryKind, List<Category>>{};
                    for (final c in filtered) {
                      kinds.putIfAbsent(c.kind, () => []).add(c);
                    }
                    final kindOrder = [
                      CategoryKind.expense,
                      CategoryKind.income,
                      CategoryKind.internal,
                      CategoryKind.uncategorized,
                    ];

                    return ListView.builder(
                      controller: scrollController,
                      itemCount: kindOrder
                          .where((k) => kinds.containsKey(k))
                          .length,
                      itemBuilder: (context, index) {
                        final kind =
                            kindOrder.where((k) => kinds.containsKey(k)).toList()[index];
                        final cats = kinds[kind]!;
                        return _KindGroup(
                          kind: kind,
                          categories: cats,
                          onSelect: (cat) => Navigator.of(context).pop(cat),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _KindGroup extends StatelessWidget {
  final CategoryKind kind;
  final List<Category> categories;
  final ValueChanged<Category> onSelect;

  const _KindGroup({
    required this.kind,
    required this.categories,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            kind.labelPt.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 10,
              color: BmoColors.textMuted,
            ),
          ),
        ),
        ...categories.map((cat) => ListTile(
              title: Text(
                cat.name,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: BmoColors.textPrimary,
                ),
              ),
              trailing: cat.isSystem
                  ? const Icon(Icons.lock, size: 14, color: BmoColors.textMuted)
                  : null,
              onTap: () => onSelect(cat),
              dense: true,
            )),
        const SizedBox(height: 4),
      ],
    );
  }
}

/// Botão "Gerenciar" que abre a tela de gerenciamento de categorias.
class _ManageButton extends StatelessWidget {
  final VoidCallback? onCreated;

  const _ManageButton({this.onCreated});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: TextButton.icon(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const CategoryManagementScreen(),
            ),
          );
          onCreated?.call();
        },
        icon: const Icon(Icons.tune, size: 14, color: BmoColors.textMuted),
        label: const Text(
          'Gerir',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            color: BmoColors.textMuted,
          ),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}
