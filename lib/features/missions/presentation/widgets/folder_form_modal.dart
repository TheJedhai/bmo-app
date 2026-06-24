import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/bmo_theme.dart';
import '../../data/missions_client.dart';
import '../../data/missions_providers.dart';
import '../../data/models/folder.dart';

class FolderFormModal extends ConsumerStatefulWidget {
  final Folder? folder;

  const FolderFormModal({super.key, this.folder});

  bool get isEditing => folder != null;

  @override
  ConsumerState<FolderFormModal> createState() => _FolderFormModalState();
}

class _FolderFormModalState extends ConsumerState<FolderFormModal> {
  late final TextEditingController _nameCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.folder?.name ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  bool get _canSave => _nameCtrl.text.trim().isNotEmpty;

  Future<void> _save() async {
    if (!_canSave || _saving) return;

    setState(() => _saving = true);

    final folders = ref.read(foldersProvider.notifier);
    final name = _nameCtrl.text.trim();

    try {
      if (widget.isEditing) {
        await folders.edit(widget.folder!.id, name: name);
      } else {
        await folders.create(name);
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on MissionsApiException catch (e) {
      setState(() => _saving = false);
      if (!mounted) return;
      final message = switch (e.errorCode) {
        'folder_name_taken' => 'Já existe uma pasta com esse nome',
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
          maxWidth: isMobile ? double.infinity : 400,
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
                    widget.isEditing ? 'Renomear pasta' : 'Nova pasta',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: 12,
                      color: BmoColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            // Form body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _nameCtrl,
                      autofocus: true,
                      style: theme.textTheme.bodyMedium,
                      decoration: const InputDecoration(
                        hintText: 'Nome da pasta',
                        hintStyle: TextStyle(color: BmoColors.textMuted),
                      ),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _save(),
                    ),
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
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(false),
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
