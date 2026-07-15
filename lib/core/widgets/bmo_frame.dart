import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/widgets/settings_modal.dart';
import '../identity/identity_provider.dart';
import '../identity/widgets/profile_avatar.dart';
import '../theme/bmo_theme.dart';

const _kMobileBreakpoint = 600.0;

/// Casca visual do BMO ocupando a viewport inteira: borda verde nas 4
/// extremidades + tela escura no meio cobrindo todo o resto do espaço.
///
/// Também hospeda os controles de settings (engrenagem) e perfil (avatar)
/// no canto superior direito do chassi, visíveis de qualquer tela.
class BmoFrame extends ConsumerWidget {
  final Widget child;
  const BmoFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < _kMobileBreakpoint;

    final borderPadding = isMobile ? 12.0 : 28.0;
    final innerRadius = isMobile ? 12.0 : 18.0;

    // Control sizing — icons discretos com touch target >= ~40px.
    final iconSize = isMobile ? 14.0 : 16.0;
    final avatarRadius = isMobile ? 9.0 : 11.0;
    final touchPad = isMobile ? 13.0 : 14.0; // ~40px mobile, ~44px desktop

    final userAsync = ref.watch(currentUserProvider);

    return Container(
      color: BmoColors.bodyGreen,
      child: Stack(
        children: [
          // Inner screen
          Padding(
            padding: EdgeInsets.all(borderPadding),
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: BmoColors.screenBg,
                borderRadius: BorderRadius.circular(innerRadius),
              ),
              child: child,
            ),
          ),
          // Controls anchored to top-right of the green chassis.
          // They naturally overlap the inner content — that's intentional
          // so they fit even when the border is thin (mobile).
          Positioned(
            top: isMobile ? 0.0 : 2.0,
            right: isMobile ? 0.0 : 4.0,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Settings gear
                IconButton(
                  icon: Icon(Icons.settings, size: iconSize),
                  color: BmoColors.screenBg,
                  tooltip: 'Configurações',
                  padding: EdgeInsets.all(touchPad),
                  constraints: const BoxConstraints(),
                  onPressed: () => showSettingsModal(context),
                ),
                // Profile avatar — tap to switch profile
                userAsync.whenOrNull(
                      data: (user) {
                        if (user == null) return const SizedBox.shrink();
                        return GestureDetector(
                          onTap: () =>
                              ref.read(currentUserProvider.notifier).clearUser(),
                          child: Padding(
                            padding: EdgeInsets.all(touchPad),
                            child: ProfileAvatar(
                              profile: user,
                              radius: avatarRadius,
                            ),
                          ),
                        );
                      },
                    ) ??
                    const SizedBox.shrink(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
