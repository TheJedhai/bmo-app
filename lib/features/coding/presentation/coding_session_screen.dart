import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/bmo_theme.dart';
import '../data/coding_client.dart';
import '../data/coding_providers.dart';
import '../data/models/coding_session.dart';

/// Tela de lista de conversas de um projeto — /coding/:projectId.
class CodingSessionScreen extends ConsumerWidget {
  const CodingSessionScreen({super.key, required this.projectId});

  final int projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionsProvider(projectId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Builder(
        builder: (context) => Column(
        children: [
          _Header(
            projectId: projectId,
            onNewSession: () => _createSession(context, ref),
          ),
          Expanded(
            child: sessionsAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: BmoColors.accentGreen,
              ),
            ),
            error: (error, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline,
                      size: 40, color: BmoColors.accentRed),
                  const SizedBox(height: 8),
                  Text(
                    '$error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: BmoColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () =>
                        ref.invalidate(sessionsProvider(projectId)),
                    style: FilledButton.styleFrom(
                      backgroundColor: BmoColors.accentGreen,
                      foregroundColor: const Color(0xFF0F1115),
                    ),
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            ),
            data: (sessions) {
              // Ordena por updated_at decrescente, fallback para created_at
              final sorted = List<CodingSession>.from(sessions)
                ..sort((a, b) {
                  final aTime = a.updatedAt ?? a.createdAt;
                  final bTime = b.updatedAt ?? b.createdAt;
                  return bTime.compareTo(aTime);
                });

              if (sorted.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chat_bubble_outline,
                          size: 48,
                          color: BmoColors.accentGreen
                              .withValues(alpha: 0.4)),
                      const SizedBox(height: 12),
                      const Text(
                        'Nenhuma conversa ainda',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: BmoColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                itemCount: sorted.length,
                itemBuilder: (context, index) {
                  return _SessionCard(
                    session: sorted[index],
                    onTap: () {
                      // Fatia 2 — por enquanto não navega.
                    },
                    onRename: () =>
                        _renameSession(context, ref, sorted[index]),
                    onDelete: () =>
                        _confirmDelete(context, ref, sorted[index]),
                  );
                },
              );
            },
          ),
        ),
      ],
        ),
      ),
    );
  }

  Future<void> _createSession(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => _SessionFormDialog(controller: nameCtrl),
    );
    nameCtrl.dispose();

    if (result == null || result.trim().isEmpty) return;

    try {
      final client = ref.read(codingClientProvider);
      await client.createSession(projectId, {'title': result.trim()});
      ref.invalidate(sessionsProvider(projectId));
    } on CodingApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    }
  }

  Future<void> _renameSession(
    BuildContext context,
    WidgetRef ref,
    CodingSession session,
  ) async {
    final nameCtrl = TextEditingController(text: session.name);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => _SessionFormDialog(
        controller: nameCtrl,
        title: 'Renomear conversa',
        acceptLabel: 'Salvar',
      ),
    );
    nameCtrl.dispose();

    if (result == null || result.trim().isEmpty) return;

    try {
      final client = ref.read(codingClientProvider);
      await client.updateSession(
          projectId, session.sessionId, {'title': result.trim()});
      ref.invalidate(sessionsProvider(projectId));
    } on CodingApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    CodingSession session,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BmoColors.screenBgElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: BmoColors.accentRed.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        title: const Text(
          'Excluir conversa',
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 11,
            color: BmoColors.accentRed,
          ),
        ),
        content: Text(
          'Excluir "${session.name}"?',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            color: BmoColors.textPrimary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Cancelar',
              style: TextStyle(
                fontFamily: 'Inter',
                color: BmoColors.textSecondary,
              ),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: BmoColors.accentRed,
              foregroundColor: const Color(0xFF0F1115),
            ),
            child: const Text(
              'Excluir',
              style: TextStyle(
                  fontFamily: 'Inter', fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final client = ref.read(codingClientProvider);
        await client.deleteSession(projectId, session.sessionId);
        ref.invalidate(sessionsProvider(projectId));
      } on CodingApiException catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(e.message)));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Erro: $e')));
        }
      }
    }
  }
}

// ============================================================
// Header
// ============================================================

class _Header extends StatelessWidget {
  const _Header({required this.projectId, required this.onNewSession});

  final int projectId;
  final VoidCallback onNewSession;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              if (GoRouter.of(context).canPop()) {
                GoRouter.of(context).pop();
              } else {
                GoRouter.of(context).go('/');
              }
            },
            icon: const Icon(Icons.arrow_back, size: 20),
            color: BmoColors.textSecondary,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          const SizedBox(width: 8),
          Text(
            'CONVERSAS',
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 14,
              color: BmoColors.accentGreen,
              shadows: [
                Shadow(
                  color: BmoColors.accentGreen.withValues(alpha: 0.3),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: onNewSession,
            icon: const Icon(Icons.add, size: 18),
            label: const Text(
              'Nova conversa',
              style:
                  TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: BmoColors.accentGreen,
              foregroundColor: const Color(0xFF0F1115),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Session card
// ============================================================

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  final CodingSession session;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  String _formatTimestamp(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inMinutes < 1) return 'agora';
      if (diff.inMinutes < 60) return '${diff.inMinutes}min atrás';
      if (diff.inHours < 24) return '${diff.inHours}h atrás';
      final d = dt.day.toString().padLeft(2, '0');
      final m = dt.month.toString().padLeft(2, '0');
      return '$d/$m';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: BmoColors.screenBgElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: BmoColors.accentGreen.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: BmoColors.accentGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.chat_bubble_outline,
                  size: 20,
                  color: BmoColors.accentGreen,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.name,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: BmoColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatTimestamp(session.updatedAt ?? session.createdAt),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: BmoColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_horiz,
                  color: BmoColors.textMuted.withValues(alpha: 0.6),
                  size: 20,
                ),
                color: BmoColors.screenBgElevated,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: BmoColors.accentGreen.withValues(alpha: 0.2),
                  ),
                ),
                onSelected: (action) {
                  switch (action) {
                    case 'rename':
                      onRename();
                      break;
                    case 'delete':
                      onDelete();
                      break;
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'rename',
                    child: _MenuRow(Icons.edit, 'Renomear'),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child:
                        _MenuRow(Icons.delete_outline, 'Excluir', danger: true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Session form dialog (inline — usado só aqui)
// ============================================================

class _SessionFormDialog extends StatefulWidget {
  const _SessionFormDialog({
    required this.controller,
    this.title = 'Nova conversa',
    this.acceptLabel = 'Criar',
  });

  final TextEditingController controller;
  final String title;
  final String acceptLabel;

  @override
  State<_SessionFormDialog> createState() => _SessionFormDialogState();
}

class _SessionFormDialogState extends State<_SessionFormDialog> {
  final _formKey = GlobalKey<FormState>();

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
        widget.title,
        style: TextStyle(
          fontFamily: 'PressStart2P',
          fontSize: 11,
          color: BmoColors.accentGreen,
        ),
      ),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: widget.controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Nome da conversa',
            hintStyle: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: BmoColors.textMuted,
            ),
            filled: true,
            fillColor: BmoColors.screenBg,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: BmoColors.textMuted.withValues(alpha: 0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: BmoColors.textMuted.withValues(alpha: 0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: BmoColors.accentGreen),
            ),
          ),
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            color: BmoColors.textPrimary,
          ),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
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
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(context).pop(widget.controller.text.trim());
          },
          style: FilledButton.styleFrom(
            backgroundColor: BmoColors.accentGreen,
            foregroundColor: const Color(0xFF0F1115),
          ),
          child: Text(
            widget.acceptLabel,
            style: const TextStyle(
                fontFamily: 'Inter', fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow(this.icon, this.label, {this.danger = false});

  final IconData icon;
  final String label;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? BmoColors.accentRed : BmoColors.textPrimary;
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: color)),
      ],
    );
  }
}
