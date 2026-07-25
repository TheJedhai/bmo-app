import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/bmo_theme.dart';
import '../../../core/widgets/bmo_back_button.dart';
import '../data/categorization_providers.dart';
import '../data/models/category.dart';

/// Tela de gerenciamento de categorias: listar, criar, renomear, reordenar, deletar.
class CategoryManagementScreen extends ConsumerStatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  ConsumerState<CategoryManagementScreen> createState() =>
      _CategoryManagementScreenState();
}

class _CategoryManagementScreenState
    extends ConsumerState<CategoryManagementScreen> {
  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: BmoColors.screenBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const BmoBackButton(),
        title: Text(
          'Categorias',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(),
        backgroundColor: BmoColors.accentGreen,
        child: const Icon(Icons.add, color: BmoColors.screenBg),
      ),
      body: categoriesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: BmoColors.accentGreen),
        ),
        error: (e, _) => Center(
          child: Text(
            'Erro ao carregar categorias.',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: BmoColors.textSecondary,
            ),
          ),
        ),
        data: (categories) {
          if (categories.isEmpty) {
            return const Center(
              child: Text(
                'Nenhuma categoria cadastrada.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: BmoColors.textMuted,
                ),
              ),
            );
          }

          final kinds = <CategoryKind, List<Category>>{};
          for (final c in categories) {
            kinds.putIfAbsent(c.kind, () => []).add(c);
          }
          final kindOrder = [
            CategoryKind.expense,
            CategoryKind.income,
            CategoryKind.internal,
            CategoryKind.uncategorized,
          ];

          return ListView(
            children: kindOrder.where((k) => kinds.containsKey(k)).expand((kind) {
              final cats = kinds[kind]!;
              return [
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
                ...cats.map((cat) => _CategoryTile(
                      category: cat,
                      onRename: () => _showRenameDialog(cat),
                      onDelete: cat.isSystem
                          ? null
                          : () => _showDeleteDialog(cat),
                    )),
              ];
            }).toList(),
          );
        },
      ),
    );
  }

  Future<void> _showCreateDialog() async {
    final nameController = TextEditingController();
    CategoryKind selectedKind = CategoryKind.expense;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BmoColors.screenBgElevated,
        title: const Text('Nova categoria',
            style: TextStyle(
              fontFamily: 'Inter',
              color: BmoColors.textPrimary,
            )),
        content: StatefulBuilder(
          builder: (ctx, setDialogState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: BmoColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Nome da categoria',
                    hintStyle: const TextStyle(
                      fontFamily: 'Inter',
                      color: BmoColors.textMuted,
                    ),
                    filled: true,
                    fillColor: BmoColors.screenBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<CategoryKind>(
                  initialValue: selectedKind,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: BmoColors.textPrimary,
                  ),
                  dropdownColor: BmoColors.screenBgElevated,
                  decoration: InputDecoration(
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
                    if (v != null) setDialogState(() => selectedKind = v);
                  },
                ),
              ],
            );
          },
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
    );

    if (result == true && nameController.text.trim().isNotEmpty) {
      try {
        await ref.read(categoriesProvider.notifier).create(
              name: nameController.text.trim(),
              kind: selectedKind.name,
            );
      } catch (e) {
        if (mounted) {
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
  }

  Future<void> _showRenameDialog(Category cat) async {
    final nameController = TextEditingController(text: cat.name);

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BmoColors.screenBgElevated,
        title: const Text('Renomear categoria',
            style: TextStyle(
              fontFamily: 'Inter',
              color: BmoColors.textPrimary,
            )),
        content: TextField(
          controller: nameController,
          autofocus: true,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            color: BmoColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: 'Novo nome',
            hintStyle: const TextStyle(
              fontFamily: 'Inter',
              color: BmoColors.textMuted,
            ),
            filled: true,
            fillColor: BmoColors.screenBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
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
            child: const Text('Salvar',
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: BmoColors.accentGreen,
                )),
          ),
        ],
      ),
    );

    if (result == true && nameController.text.trim().isNotEmpty) {
      try {
        await ref
            .read(categoriesProvider.notifier)
            .updateCategory(cat.id, name: nameController.text.trim());
      } catch (e) {
        if (mounted) {
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
  }

  Future<void> _showDeleteDialog(Category cat) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BmoColors.screenBgElevated,
        title: const Text('Deletar categoria',
            style: TextStyle(
              fontFamily: 'Inter',
              color: BmoColors.textPrimary,
            )),
        content: Text(
          'Lançamentos em "${cat.name}" irão para "Sem categoria". '
          'Esta ação não pode ser desfeita.',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            color: BmoColors.textSecondary,
          ),
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
            child: const Text('Deletar',
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: BmoColors.accentRed,
                )),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        await ref.read(categoriesProvider.notifier).delete(cat.id);
      } catch (e) {
        if (mounted) {
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
  }
}

class _CategoryTile extends StatelessWidget {
  final Category category;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  const _CategoryTile({
    required this.category,
    this.onRename,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        category.name,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          color: BmoColors.textPrimary,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (category.isSystem)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child:
                  Icon(Icons.lock, size: 14, color: BmoColors.textMuted),
            ),
          if (onRename != null)
            IconButton(
              icon: const Icon(Icons.edit, size: 16, color: BmoColors.textMuted),
              onPressed: onRename,
              visualDensity: VisualDensity.compact,
            ),
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  size: 16, color: BmoColors.accentRed),
              onPressed: onDelete,
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
      dense: true,
    );
  }
}
