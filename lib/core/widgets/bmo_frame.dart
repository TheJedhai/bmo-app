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
/// Os controles de settings (engrenagem, canto superior direito) e perfil
/// (avatar, canto inferior direito) ficam sobre a faixa verde do chassi,
/// ancorados com um pequeno offset da borda externa.
class BmoFrame extends ConsumerWidget {
  final Widget child;
  const BmoFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < _kMobileBreakpoint;

    final borderPadding = isMobile ? 12.0 : 28.0;
    final innerRadius = isMobile ? 12.0 : 18.0;

    // ---- Control sizing & positioning -------------------------------------
    //
    // Each control (gear / avatar) is a visual circle centered inside a
    // touch hitbox (touchSize × touchSize). The hitbox is anchored to the
    // outer edge via Positioned(right:, top: or bottom:).
    //
    // Inner edge of the visual circle from the outer edge:
    //   offset + (touchSize + circleDiameter) / 2
    // This must be ≤ borderPadding so the circle never crosses into the
    // dark screen area. Solving for offset:
    //   offset = borderPadding - (touchSize + circleDiameter) / 2
    //
    // Desktop (borderPadding=28, touchSize=44, D=32): 28 - 38 = -10
    // Mobile  (borderPadding=12, touchSize=40, D=26): 12 - 33 = -21
    //
    // Negative offsets overflow the outer edge of the green Container;
    // Flutter's Stack doesn't clip, so the circle stays visible over the
    // green chassis — and out of the dark screen.
    final controlOffset = isMobile ? -21.0 : -10.0;
    final gearDiameter = isMobile ? 26.0 : 32.0;
    final gearIconSize = isMobile ? 14.0 : 18.0;
    final touchSize = isMobile ? 40.0 : 44.0;
    final avatarOuterDiam = isMobile ? 26.0 : 32.0;
    final avatarInnerRadius = isMobile ? 8.0 : 10.0;

    final userAsync = ref.watch(currentUserProvider);

    return Container(
      color: BmoColors.bodyGreen,
      child: Stack(
        children: [
          // ---- Inner screen ----
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

          // ---- Settings gear (top-right, on green band) ----
          Positioned(
            top: controlOffset,
            right: controlOffset,
            child: _ControlHitbox(
              size: touchSize,
              onTap: () => showSettingsModal(context),
              child: _DarkCircle(
                diameter: gearDiameter,
                child: Icon(Icons.settings,
                    size: gearIconSize, color: BmoColors.accentGreen),
              ),
            ),
          ),

          // ---- Profile avatar (bottom-right, on green band) ----
          Positioned(
            bottom: controlOffset,
            right: controlOffset,
            child: userAsync.whenOrNull(
                  data: (user) {
                    if (user == null) return const SizedBox.shrink();
                    return _ControlHitbox(
                      size: touchSize,
                      onTap: () =>
                          ref.read(currentUserProvider.notifier).clearUser(),
                      child: _FramedAvatar(
                        profile: user,
                        outerDiameter: avatarOuterDiam,
                        innerRadius: avatarInnerRadius,
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

// ============================================================================
// Private helpers
// ============================================================================

/// Hitbox invisível que garante área de toque ≥ [size]×[size] mesmo quando
/// o círculo visual é menor (importante no mobile onde a faixa verde é fina).
///
/// O [child] (círculo visível) é centralizado dentro do hitbox; o excedente
/// transborda para dentro da tela escura, mas não afeta layout do conteúdo.
class _ControlHitbox extends StatelessWidget {
  final double size;
  final VoidCallback onTap;
  final Widget child;

  const _ControlHitbox({
    required this.size,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: size,
        height: size,
        child: Center(child: child),
      ),
    );
  }
}

/// Círculo escuro ([BmoColors.screenBg]) usado como fundo de contraste
/// para controles que ficam sobre o chassi verde claro.
class _DarkCircle extends StatelessWidget {
  final double diameter;
  final Widget child;

  const _DarkCircle({required this.diameter, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: const BoxDecoration(
        color: BmoColors.screenBg,
        shape: BoxShape.circle,
      ),
      child: Center(child: child),
    );
  }
}

/// Avatar de perfil com fundo escuro e borda fina verde para contraste
/// contra o chassi claro ([BmoColors.bodyGreen]).
///
/// Envolve o [ProfileAvatar] num círculo sólido [BmoColors.screenBg] com
/// borda de 1.5px em [BmoColors.accentGreen].
class _FramedAvatar extends StatelessWidget {
  final dynamic profile; // UserProfile
  final double outerDiameter;
  final double innerRadius;

  const _FramedAvatar({
    required this.profile,
    required this.outerDiameter,
    required this.innerRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: outerDiameter,
      height: outerDiameter,
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
