import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/identity/identity_provider.dart';
import '../../../core/identity/identity_state.dart';
import '../../../core/identity/user_profile.dart';
import '../../../core/identity/widgets/profile_avatar.dart';
import '../../../core/theme/bmo_theme.dart';
import '../data/flux_model.dart';
import '../providers/settings_provider.dart';

const _kMobileBreakpoint = 600.0;

// ============================================================
// Entry point
// ============================================================

void showSettingsModal(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (_) => const _SettingsModal(),
  );
}

// ============================================================
// Section abstraction
// ============================================================

class _SettingsSection {
  final String id;
  final String title;
  final IconData icon;
  final Widget Function(
    BuildContext context,
    WidgetRef ref,
    Map<String, String> settings,
  ) builder;

  const _SettingsSection({
    required this.id,
    required this.title,
    required this.icon,
    required this.builder,
  });
}

// ============================================================
// Modal
// ============================================================

class _SettingsModal extends ConsumerStatefulWidget {
  const _SettingsModal();

  @override
  ConsumerState<_SettingsModal> createState() => _SettingsModalState();
}

class _SettingsModalState extends ConsumerState<_SettingsModal> {
  final _selectedSectionId = StateProvider<String>((ref) => 'image');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(settingsProvider.notifier).refresh();
    });
  }

  // --- Section list (extensible — add entries here for new sections) ---

  static final _sections = <_SettingsSection>[
    _SettingsSection(
      id: 'profile',
      title: 'Perfil',
      icon: Icons.person_outline,
      builder: _buildProfileSection,
    ),
    _SettingsSection(
      id: 'image',
      title: 'Imagem',
      icon: Icons.image_outlined,
      builder: _buildImageSection,
    ),
  ];

  // --- Helpers ---

  _SettingsSection _findSection(String id) {
    return _sections.firstWhere(
      (s) => s.id == id,
      orElse: () => _sections.first,
    );
  }

  // ==========================================================
  // Build
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < _kMobileBreakpoint;
    final settingsAsync = ref.watch(settingsProvider);
    final selectedId = ref.watch(_selectedSectionId);

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
          maxWidth: isMobile ? double.infinity : 600,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            _SettingsHeader(
              onClose: () => Navigator.of(context).pop(),
            ),
            // Body
            Flexible(
              child: settingsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => _SettingsErrorState(
                  error: e,
                  onRetry: () =>
                      ref.read(settingsProvider.notifier).refresh(),
                ),
                data: (settings) {
                  final section = _findSection(selectedId);
                  return _buildLayout(
                    isMobile: isMobile,
                    selectedId: selectedId,
                    section: section,
                    settings: settings,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // Layout: desktop vs mobile
  // ==========================================================

  Widget _buildLayout({
    required bool isMobile,
    required String selectedId,
    required _SettingsSection section,
    required Map<String, String> settings,
  }) {
    if (isMobile) {
      return _MobileLayout(
        sections: _sections,
        selectedId: selectedId,
        onSectionChanged: (id) =>
            ref.read(_selectedSectionId.notifier).state = id,
        content: section.builder(context, ref, settings),
      );
    }
    return _DesktopLayout(
      sections: _sections,
      selectedId: selectedId,
      onSectionChanged: (id) =>
          ref.read(_selectedSectionId.notifier).state = id,
      content: section.builder(context, ref, settings),
    );
  }

  // ==========================================================
  // Profile section builder
  // ==========================================================

  static Widget _buildProfileSection(
    BuildContext context,
    WidgetRef ref,
    Map<String, String> settings,
  ) {
    final userAsync = ref.watch(currentUserProvider);
    final features = ref.watch(enabledFeaturesProvider);

    return userAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ProfileError(
        error: e.toString(),
        onRetry: () => ref.read(currentUserProvider.notifier),
      ),
      data: (user) => _ProfileContent(
        user: user,
        features: features,
        onChangeProfile: () {
          ref.read(currentUserProvider.notifier).clearUser();
        },
      ),
    );
  }

  // ==========================================================
  // Image section builder
  // ==========================================================

  static Widget _buildImageSection(
    BuildContext context,
    WidgetRef ref,
    Map<String, String> settings,
  ) {
    return _ImageSettingsSection(
      settings: settings,
      onModelChanged: (newModel) async {
        try {
          await ref
              .read(settingsProvider.notifier)
              .updateSetting('image.default_model', newModel);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Modelo padrão atualizado'),
                backgroundColor: BmoColors.accentGreen,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Falha ao atualizar: $e'),
                backgroundColor: Colors.redAccent,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      },
    );
  }
}

// ============================================================
// Desktop layout: sidebar + content
// ============================================================

class _DesktopLayout extends StatelessWidget {
  final List<_SettingsSection> sections;
  final String selectedId;
  final ValueChanged<String> onSectionChanged;
  final Widget content;

  const _DesktopLayout({
    required this.sections,
    required this.selectedId,
    required this.onSectionChanged,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sidebar
        SizedBox(
          width: 180,
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            shrinkWrap: true,
            children: sections.map((section) {
              final isSelected = section.id == selectedId;
              return _SectionTile(
                section: section,
                isSelected: isSelected,
                onTap: () => onSectionChanged(section.id),
              );
            }).toList(),
          ),
        ),
        // Divider
        VerticalDivider(
          width: 1,
          color: BmoColors.textMuted.withValues(alpha: 0.3),
        ),
        // Content
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: content,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// Mobile layout: horizontal chips + content
// ============================================================

class _MobileLayout extends StatelessWidget {
  final List<_SettingsSection> sections;
  final String selectedId;
  final ValueChanged<String> onSectionChanged;
  final Widget content;

  const _MobileLayout({
    required this.sections,
    required this.selectedId,
    required this.onSectionChanged,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Horizontal chip row
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: sections.map((section) {
              final isSelected = section.id == selectedId;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _SectionChip(
                  section: section,
                  isSelected: isSelected,
                  onTap: () => onSectionChanged(section.id),
                ),
              );
            }).toList(),
          ),
        ),
        Divider(
          color: BmoColors.textMuted.withValues(alpha: 0.3),
          height: 1,
        ),
        // Content
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: content,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// Header
// ============================================================

class _SettingsHeader extends StatelessWidget {
  final VoidCallback onClose;

  const _SettingsHeader({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
      child: Row(
        children: [
          Text(
            'Configurações',
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

// ============================================================
// Section tile (desktop sidebar)
// ============================================================

class _SectionTile extends StatelessWidget {
  final _SettingsSection section;
  final bool isSelected;
  final VoidCallback onTap;

  const _SectionTile({
    required this.section,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: isSelected
            ? BmoColors.accentGreen.withValues(alpha: 0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  section.icon,
                  size: 18,
                  color: isSelected
                      ? BmoColors.accentGreen
                      : BmoColors.textSecondary,
                ),
                const SizedBox(width: 10),
                Text(
                  section.title,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected
                        ? BmoColors.accentGreen
                        : BmoColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Section chip (mobile tabs)
// ============================================================

class _SectionChip extends StatelessWidget {
  final _SettingsSection section;
  final bool isSelected;
  final VoidCallback onTap;

  const _SectionChip({
    required this.section,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(
        section.icon,
        size: 16,
        color: isSelected ? BmoColors.accentGreen : BmoColors.textSecondary,
      ),
      label: Text(section.title),
      labelStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 13,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
        color: isSelected ? BmoColors.accentGreen : BmoColors.textSecondary,
      ),
      backgroundColor:
          isSelected ? BmoColors.accentGreen.withValues(alpha: 0.15) : BmoColors.screenBg,
      side: BorderSide(
        color: isSelected
            ? BmoColors.accentGreen
            : BmoColors.textMuted.withValues(alpha: 0.3),
        width: 1,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      onPressed: onTap,
    );
  }
}

// ============================================================
// Image settings section
// ============================================================

class _ImageSettingsSection extends ConsumerWidget {
  final Map<String, String> settings;
  final void Function(String newModel) onModelChanged;

  const _ImageSettingsSection({
    required this.settings,
    required this.onModelChanged,
  });

  static const _defaultModelKey = 'image.default_model';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modelsAsync = ref.watch(imageModelsProvider);
    final currentModel = settings[_defaultModelKey];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section title
        Text(
          'Modelo Padrão',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: BmoColors.textPrimary,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'Modelo usado por padrão ao gerar imagens.',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            color: BmoColors.textMuted,
          ),
        ),
        const SizedBox(height: 20),
        // Dropdown
        modelsAsync.when(
          loading: () => const SizedBox(
            height: 48,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: BmoColors.accentGreen,
                ),
              ),
            ),
          ),
          error: (e, _) => Text(
            'Falha ao carregar modelos: $e',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: Colors.redAccent,
            ),
          ),
          data: (models) {
            // Resolve effective model: use the saved setting if it matches a
            // known model, otherwise fall back to the factory default.
            final effectiveModel =
                models.any((m) => m.name == currentModel)
                    ? currentModel!
                    : models.firstWhere(
                        (m) => m.isDefault,
                        orElse: () => models.first,
                      ).name;

            return _ModelDropdown(
              models: models,
              currentModel: effectiveModel,
              onChanged: onModelChanged,
            );
          },
        ),
      ],
    );
  }
}

// ============================================================
// Model dropdown
// ============================================================

class _ModelDropdown extends StatelessWidget {
  final List<FluxModel> models;
  final String currentModel;
  final ValueChanged<String> onChanged;

  const _ModelDropdown({
    required this.models,
    required this.currentModel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: BmoColors.screenBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: BmoColors.textMuted.withValues(alpha: 0.3),
        ),
      ),
      child: DropdownButton<String>(
        value: currentModel,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        dropdownColor: BmoColors.screenBgElevated,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          color: BmoColors.textPrimary,
        ),
        icon: const Icon(Icons.expand_more, color: BmoColors.textSecondary),
        items: models.map(
          (model) => DropdownMenuItem<String>(
            value: model.name,
            child: Text(model.name),
          ),
        ).toList(),
        onChanged: (value) {
          if (value != null && value != currentModel) {
            onChanged(value);
          }
        },
      ),
    );
  }
}

// ============================================================
// Error state
// ============================================================

class _SettingsErrorState extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _SettingsErrorState({required this.error, required this.onRetry});

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
              'Falha ao carregar',
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
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Profile section widgets
// ============================================================

class _ProfileContent extends StatelessWidget {
  final UserProfile? user;
  final Set<String> features;
  final VoidCallback onChangeProfile;

  const _ProfileContent({
    required this.user,
    required this.features,
    required this.onChangeProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Perfil atual',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: BmoColors.textPrimary,
              ),
        ),
        const SizedBox(height: 16),
        // Avatar + nome
        Row(
          children: [
            if (user != null)
              ProfileAvatar(profile: user!, radius: 28)
            else
              CircleAvatar(
                radius: 28,
                backgroundColor: BmoColors.textMuted.withValues(alpha: 0.2),
                child: const Icon(Icons.person, color: BmoColors.textMuted),
              ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.name ?? 'Sem perfil',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: BmoColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user != null ? 'ID: ${user!.id}' : 'Selecione um perfil',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: BmoColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Botão trocar perfil
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onChangeProfile,
            icon: const Icon(Icons.swap_horiz, size: 18),
            label: const Text('Trocar perfil'),
            style: OutlinedButton.styleFrom(
              foregroundColor: BmoColors.accentGreen,
              side: const BorderSide(color: BmoColors.accentGreen),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Isso limpa o perfil salvo e volta à tela de seleção.',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            color: BmoColors.textMuted,
          ),
        ),
        // Feature keys info
        if (features.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'Features habilitadas',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: BmoColors.textPrimary,
                ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: features.map((key) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: BmoColors.accentGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  key,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: BmoColors.accentGreen,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

class _ProfileError extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ProfileError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 32),
            const SizedBox(height: 8),
            const Text(
              'Falha ao carregar perfil',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: Colors.redAccent,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: BmoColors.textMuted,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onRetry,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}

