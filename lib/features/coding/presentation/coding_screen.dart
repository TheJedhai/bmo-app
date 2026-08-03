import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/identity/identity_state.dart';
import '../../../core/theme/bmo_theme.dart';
import '../data/coding_providers.dart';
import '../data/models/coding_project.dart';
import 'widgets/project_form_dialog.dart';

/// Tela de lista de projetos — /coding.
class CodingScreen extends ConsumerWidget {
  const CodingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Gate opt-in: se o perfil atual não tem a feature 'coding', redireciona
    // para a raiz. Este padrão serve de referência para outras features com
    // gate opt-in (ex: 'finances').
    final features = ref.watch(enabledFeaturesProvider);
    if (!features.contains('coding')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) GoRouter.of(context).go('/');
      });
      return const SizedBox.shrink();
    }

    final projectsAsync = ref.watch(projectsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Builder(
        builder: (context) => Column(
      children: [
        _Header(
          onNewProject: () => _openProjectForm(context, ref),
        ),
        Expanded(
          child: projectsAsync.when(
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
                        ref.read(projectsProvider.notifier).refresh(),
                    style: FilledButton.styleFrom(
                      backgroundColor: BmoColors.accentGreen,
                      foregroundColor: const Color(0xFF0F1115),
                    ),
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            ),
            data: (projects) {
              if (projects.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.code,
                          size: 48,
                          color: BmoColors.accentGreen
                              .withValues(alpha: 0.4)),
                      const SizedBox(height: 12),
                      const Text(
                        'Nenhum projeto ainda',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: BmoColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Crie um projeto para começar a programar',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: BmoColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                itemCount: projects.length,
                itemBuilder: (context, index) {
                  return _ProjectCard(
                    project: projects[index],
                    onTap: () {
                      GoRouter.of(context)
                          .push('/coding/${projects[index].id}');
                    },
                    onEdit: () =>
                        _openProjectForm(context, ref, existing: projects[index]),
                    onDelete: () =>
                        _confirmDelete(context, ref, projects[index]),
                    onSync: () {
                      ref
                          .read(projectsProvider.notifier)
                          .syncProject(projects[index].id);
                    },
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

  Future<void> _openProjectForm(
    BuildContext context,
    WidgetRef ref, {
    CodingProject? existing,
  }) async {
    final result = await ProjectFormDialog.show(context, initial: existing);
    if (result == null) return;

    try {
      if (existing != null) {
        await ref
            .read(projectsProvider.notifier)
            .updateProject(existing.id, result.toJson());
      } else {
        await ref
            .read(projectsProvider.notifier)
            .createProject(result.toJson());
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    CodingProject project,
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
          'Excluir projeto',
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 11,
            color: BmoColors.accentRed,
          ),
        ),
        content: Text(
          'Excluir "${project.name}"? Esta ação não pode ser desfeita.',
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
        await ref.read(projectsProvider.notifier).deleteProject(project.id);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro: $e')),
          );
        }
      }
    }
  }
}

// ============================================================
// Header
// ============================================================

class _Header extends StatelessWidget {
  const _Header({required this.onNewProject});

  final VoidCallback onNewProject;

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
            'CODING',
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
            onPressed: onNewProject,
            icon: const Icon(Icons.add, size: 18),
            label: const Text(
              'Novo projeto',
              style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
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
// Project card
// ============================================================

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.project,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onSync,
  });

  final CodingProject project;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSync;

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
              // Ícone
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: BmoColors.accentGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.code,
                  size: 20,
                  color: BmoColors.accentGreen,
                ),
              ),
              const SizedBox(width: 14),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.name,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: BmoColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      project.primaryPath,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: BmoColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              // Ações
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
                    case 'edit':
                      onEdit();
                      break;
                    case 'sync':
                      onSync();
                      break;
                    case 'delete':
                      onDelete();
                      break;
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: _MenuRow(Icons.edit, 'Editar'),
                  ),
                  const PopupMenuItem(
                    value: 'sync',
                    child: _MenuRow(Icons.sync, 'Sincronizar'),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: _MenuRow(Icons.delete_outline, 'Excluir',
                        danger: true),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right,
                  size: 18, color: BmoColors.textMuted.withValues(alpha: 0.5)),
            ],
          ),
        ),
      ),
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
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            color: color,
          ),
        ),
      ],
    );
  }
}
