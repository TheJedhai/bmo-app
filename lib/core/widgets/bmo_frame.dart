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
/// Hospeda controles de settings (engrenagem, canto superior direito) e
/// perfil (avatar, canto inferior direito) ancorados dentro da tela escura,
/// visíveis de qualquer aba.
class BmoFrame extends ConsumerWidget {
  final Widget child;
  const BmoFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < _kMobileBreakpoint;

    final borderPadding = isMobile ? 12.0 : 28.0;
    final innerRadius = isMobile ? 12.0 : 18.0;

    // ---- Gear (top-right corner) -------------------------------------------
    final gearIconSize = isMobile ? 14.0 : 16.0;
    final gearTouchPad = isMobile ? 13.0 : 14.0; // ~40px / ~44px target

    // ---- Avatar (bottom-right, above dock) ---------------------------------
    //
    // O dock de navegação ocupa a base da tela interna (56px mobile, 64px
    // desktop).  Ancorar o avatar no canto inferior causaria sobreposição
    // visual com o dock em ambas as resoluções, então ele é posicionado
    // logo acima do dock com um pequeno respiro.
    final dockHeight = isMobile ? 56.0 : 64.0;
    final dockGap = isMobile ? 4.0 : 8.0;
    final avatarInnerRadius = isMobile ? 10.0 : 12.0;
    final avatarOuterRadius = avatarInnerRadius + 2.0; // espaço p/ borda
    final avatarTouchPad = 8.0; // (outerDiameter 20/24) + 2×8 = 36/40px

    // ---- Offsets ancorados na borda interna da tela escura ------------------
    //
    // Somamos o touch-padding ao borderPadding para que o controle inteiro
    // (área de toque + ícone) fique dentro da tela escura, sem vazar para
    // a moldura verde.
    final gearInset = borderPadding + gearTouchPad; // top & right
    final avatarRightInset = borderPadding + avatarTouchPad;
    final avatarBottom = borderPadding + dockHeight + dockGap;

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

          // ---- Settings gear (top-right) ----
          Positioned(
            top: gearInset,
            right: gearInset,
            child: IconButton(
              icon: Icon(Icons.settings, size: gearIconSize),
              color: BmoColors.screenBg,
              tooltip: 'Configurações',
              padding: EdgeInsets.all(gearTouchPad),
              constraints: const BoxConstraints(),
              onPressed: () => showSettingsModal(context),
            ),
          ),

          // ---- Profile avatar (bottom-right, acima do dock) ----
          Positioned(
            bottom: avatarBottom,
            right: avatarRightInset,
            child: userAsync.whenOrNull(
                  data: (user) {
                    if (user == null) return const SizedBox.shrink();
                    return GestureDetector(
                      onTap: () =>
                          ref.read(currentUserProvider.notifier).clearUser(),
                      child: Padding(
                        padding: EdgeInsets.all(avatarTouchPad),
                        child: _FramedAvatar(
                          profile: user,
                          innerRadius: avatarInnerRadius,
                          outerRadius: avatarOuterRadius,
                        ),
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

/// Avatar de perfil com fundo escuro e borda fina verde para contraste
/// contra o chassi claro ([BmoColors.bodyGreen]).
///
/// Diferente do [ProfileAvatar] puro (que usa fundo translúcido e ficaria
/// invisível sobre o chassi), este envolve o avatar num círculo sólido
/// [BmoColors.screenBg] com borda de 1.5px em [BmoColors.accentGreen].
class _FramedAvatar extends StatelessWidget {
  final dynamic profile; // UserProfile
  final double innerRadius;
  final double outerRadius;

  const _FramedAvatar({
    required this.profile,
    required this.innerRadius,
    required this.outerRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: outerRadius * 2,
      height: outerRadius * 2,
      decoration: BoxDecoration(
        color: BmoColors.screenBg,
        shape: BoxShape.circle,
        border: Border.all(color: BmoColors.accentGreen, width: 1.5),
      ),
      child: Center(
        child: ProfileAvatar(profile: profile, radius: innerRadius),
      ),
    );
  }
}
