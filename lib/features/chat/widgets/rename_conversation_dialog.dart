import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/conversation.dart';
import '../providers/chat_providers.dart';

class RenameConversationDialog extends StatefulWidget {
  final String currentName;
  const RenameConversationDialog({super.key, required this.currentName});

  @override
  State<RenameConversationDialog> createState() =>
      _RenameConversationDialogState();
}

class _RenameConversationDialogState extends State<RenameConversationDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentName);
    _controller.selection = TextSelection.collapsed(
      offset: widget.currentName.length,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    final raw = _controller.text.trim();
    if (raw.isEmpty) return;
    if (raw == widget.currentName) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pop(raw);
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _controller.text.trim().isNotEmpty;
    return AlertDialog(
      title: const Text('Renomear conversa'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 100,
        decoration: const InputDecoration(
          hintText: 'novo nome',
        ),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _confirm(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: canSave ? _confirm : null,
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

/// Mostra o dialog e, se o usuário confirmar, faz o PUT no servidor.
/// SnackBar em caso de erro.
Future<void> showRenameDialog(
  BuildContext context,
  WidgetRef ref,
  Conversation conv,
) async {
  final newName = await showDialog<String>(
    context: context,
    builder: (_) => RenameConversationDialog(currentName: conv.name),
  );
  if (newName == null) return;
  try {
    await ref.read(conversationsProvider.notifier).rename(conv.uuid, newName);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('falha ao renomear: $e')),
      );
    }
  }
}
