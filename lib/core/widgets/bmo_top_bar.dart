import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/widgets/settings_modal.dart';
import '../identity/identity_provider.dart';
import '../identity/widgets/profile_avatar.dart';
import '../theme/bmo_theme.dart';

/// Controles do dispositivo (settings + perfil) para mobile.
///
/// No desktop esses controles ficam sobre a faixa verde do [BmoFrame];
/// no mobile a faixa é fina demais e disputa espaço com a ilha dinâmica,
/// então ficam aqui — dentro da tela escura, acima do conteúdo de toda rota.
class BmoTopBar extends ConsumerWidget {
  const BmoTopBar({super.key});

  /// Altura dos controles (48) + margem superior (16) — usada como
  /// padding-top no conteúdo das rotas para evitar sobreposição,
  /// mesma lógica de [BmoNavBar.totalBottomInset].
  static const double totalTopInset = 48 + 16;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return Positioned(
      top: 16,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Engrenagem
          SizedBox(
            width: 48,
            height: 48,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => showSettingsModal(context),
                borderRadius: BorderRadius.circular(24),
                child: const Icon(
                  Icons.settings,
                  size: 24,
                  color: BmoColors.accentGreen,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Avatar
          SizedBox(
            width: 48,
            height: 48,
            child:
                userAsync.whenOrNull(
                  data: (user) {
                    if (user == null) return const SizedBox.shrink();
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () =>
                            ref.read(currentUserProvider.notifier).clearUser(),
                        borderRadius: BorderRadius.circular(24),
                        child: ProfileAvatar(profile: user, radius: 18),
                      ),
                    );
                  },
                ) ??
                const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
