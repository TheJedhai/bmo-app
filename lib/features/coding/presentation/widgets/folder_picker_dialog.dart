import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/bmo_theme.dart';
import '../../data/coding_providers.dart';
import '../../data/models/folder_item.dart';

/// Diálogo de navegação de pastas, read-only.
///
/// Exibe subdiretórios diretos do [currentPath] (sem path = home do usuário).
/// Toque em uma pasta navega para dentro dela. Botão "Voltar" sobe um nível.
/// Botão "Selecionar" confirma o [currentPath] atual.
class FolderPickerDialog extends ConsumerStatefulWidget {
  const FolderPickerDialog({
    super.key,
    this.initialPath,
  });

  final String? initialPath;

  /// Abre o diálogo e retorna o path selecionado, ou null se cancelado.
  static Future<String?> show(
    BuildContext context, {
    String? initialPath,
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => FolderPickerDialog(initialPath: initialPath),
    );
  }

  @override
  ConsumerState<FolderPickerDialog> createState() => _FolderPickerDialogState();
}

class _FolderPickerDialogState extends ConsumerState<FolderPickerDialog> {
  late String _currentPath;
  final List<String> _pathStack = [];

  @override
  void initState() {
    super.initState();
    _currentPath = widget.initialPath ?? '';
  }

  Future<List<FolderItem>> _loadSubfolders() async {
    final client = ref.read(codingClientProvider);
    try {
      final path = _currentPath.isEmpty ? null : _currentPath;
      return await client.listSubfolders(path);
    } catch (_) {
      return [];
    }
  }

  void _navigateTo(FolderItem folder) {
    _pathStack.add(_currentPath);
    _currentPath = folder.path;
    setState(() {});
  }

  void _goBack() {
    if (_pathStack.isNotEmpty) {
      _currentPath = _pathStack.removeLast();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: BmoColors.screenBgElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: BmoColors.accentGreen.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      title: Text(
        'Escolher pasta',
        style: TextStyle(
          fontFamily: 'PressStart2P',
          fontSize: 11,
          color: BmoColors.accentGreen,
        ),
      ),
      content: SizedBox(
        width: 400,
        height: 340,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Breadcrumb
            _BreadcrumbBar(
              path: _currentPath,
              onBack: _goBack,
              canGoBack: _pathStack.isNotEmpty,
            ),
            const SizedBox(height: 8),
            // Lista de subpastas
            Expanded(
              child: FutureBuilder<List<FolderItem>>(
                future: _loadSubfolders(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: BmoColors.accentGreen,
                      ),
                    );
                  }

                  final folders = snapshot.data ?? [];

                  if (folders.isEmpty) {
                    return const Center(
                      child: Text(
                        'Nenhuma subpasta',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          color: BmoColors.textMuted,
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: folders.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        dense: true,
                        leading: const Icon(
                          Icons.folder_outlined,
                          color: BmoColors.accentYellow,
                          size: 20,
                        ),
                        title: Text(
                          folders[index].name,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            color: BmoColors.textPrimary,
                          ),
                        ),
                        onTap: () => _navigateTo(folders[index]),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text(
            'Cancelar',
            style: TextStyle(
              fontFamily: 'Inter',
              color: BmoColors.textSecondary,
            ),
          ),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_currentPath),
          style: FilledButton.styleFrom(
            backgroundColor: BmoColors.accentGreen,
            foregroundColor: const Color(0xFF0F1115),
          ),
          child: const Text(
            'Selecionar',
            style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _BreadcrumbBar extends StatelessWidget {
  const _BreadcrumbBar({
    required this.path,
    required this.onBack,
    required this.canGoBack,
  });

  final String path;
  final VoidCallback onBack;
  final bool canGoBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (canGoBack)
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, size: 18),
            color: BmoColors.textSecondary,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          )
        else
          const SizedBox(width: 32),
        const SizedBox(width: 4),
        Icon(
          Icons.folder,
          size: 16,
          color: BmoColors.accentGreen.withValues(alpha: 0.7),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            path.isEmpty ? '~' : path,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              color: BmoColors.textMuted,
            ),
          ),
        ),
      ],
    );
  }
}
