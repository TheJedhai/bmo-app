import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/widgets/settings_modal.dart';
import '../identity/identity_provider.dart';
import '../identity/widgets/profile_avatar.dart';
import '../theme/bmo_theme.dart';

const kMobileBreakpoint = 600.0;

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
    final media = MediaQuery.of(context);
    final width = media.size.width;
    final isMobile = width < kMobileBreakpoint;

    // No mobile a faixa absorve a safe area (status bar, home indicator,
    // laterais): viewPadding não zera quando o teclado sobe, ao contrário
    // de padding. Mínimo de 14px para o bezel não afinar demais em
    // aparelhos sem inset.
    final EdgeInsets borderPadding;
    if (isMobile) {
      final vp = media.viewPadding;
      borderPadding = EdgeInsets.fromLTRB(
        math.max(14.0, vp.left),
        math.max(14.0, vp.top),
        math.max(14.0, vp.right),
        math.max(14.0, vp.bottom),
      );
    } else {
      borderPadding = const EdgeInsets.all(28);
    }
    final innerRadius = isMobile ? 26.0 : 18.0;

    // ---- Control sizing & positioning -------------------------------------
    //
    // Optical centering, not mathematical. The rounded outer corner of the
    // frame shifts the perceived center inward, so controls are pushed
    // toward the straight section of the green band.
    //
    // A larger touch hitbox (≥40 px) wraps the circle via GestureDetector;
    // only the painted circle needs to look right.
    //
    // Desktop (borderPadding=28): D=22, offset=8 — 8px outer breathing
    //   room, inner edge overflows 2px into the dark screen (invisible
    //   against screenBg background).
    // Mobile  (band >= 14): D=22, offset=-5 — overflow simétrico
    //   (band é fino demais; 5px para cada lado).
    final visualDiameter = 28.0;
    final controlOffset = isMobile ? -5.0 : 8.0;
    final touchSize = isMobile ? 40.0 : 44.0;
    final gearIconSize = 20.0;
    final avatarInnerRadius = isMobile ? 7.0 : 20.0;

    final userAsync = ref.watch(currentUserProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        // Fundo claro (faixa verde) embaixo da status bar.
        statusBarBrightness: Brightness.light, // iOS — light = fundo claro
        statusBarIconBrightness: Brightness.dark, // Android
      ),
      child: Container(
        color: BmoColors.bodyGreen,
        child: Stack(
          children: [
            // ---- Inner screen ----
            Padding(
              padding: borderPadding,
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                removeBottom: true,
                removeLeft: true,
                removeRight: true,
                // O frame consome o inset; sem remover o padding qualquer
                // SafeArea interno inseta de novo por cima da faixa.
                child: ClipRSuperellipse(
                  borderRadius: BorderRadius.circular(innerRadius),
                  child: ColoredBox(
                    color: BmoColors.screenBg,
                    // Material transparente fornece o DefaultTextStyle correto
                    // aos Text sem estilo explícito. Sem ele (dashboard não
                    // tem Scaffold), o DefaultTextStyle.fallback de debug pinta
                    // sublinhado duplo amarelo embaixo dos textos.
                    child: Material(
                      type: MaterialType.transparency,
                      child: child,
                    ),
                  ),
                ),
              ),
            ),

            // ---- Settings gear (top-right, on green band) ----
            // Hidden on mobile — moves to the dashboard header.
            if (!isMobile)
              Positioned(
                top: controlOffset,
                right: controlOffset,
                child: _ControlHitbox(
                  size: touchSize,
                  alignment: Alignment.topRight,
                  onTap: () => showSettingsModal(context),
                  child: _DarkCircle(
                    diameter: visualDiameter,
                    child: Icon(
                      Icons.settings,
                      size: gearIconSize,
                      color: BmoColors.accentGreen,
                    ),
                  ),
                ),
              ),

            // ---- Profile avatar (bottom-right, on green band) ----
            // Hidden on mobile — moves to the dashboard header.
            if (!isMobile)
              Positioned(
                bottom: controlOffset,
                right: controlOffset,
                child:
                    userAsync.whenOrNull(
                      data: (user) {
                        if (user == null) return const SizedBox.shrink();
                        return _ControlHitbox(
                          size: touchSize,
                          alignment: Alignment.bottomRight,
                          onTap: () => ref
                              .read(currentUserProvider.notifier)
                              .clearUser(),
                          child: _FramedAvatar(
                            profile: user,
                            outerDiameter: visualDiameter,
                            innerRadius: avatarInnerRadius,
                          ),
                        );
                      },
                    ) ??
                    const SizedBox.shrink(),
              ),
          ],
        ),
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
/// O [child] (círculo visível) é ancorado no canto dado por [alignment]
/// (ex.: Alignment.topRight para a engrenagem, Alignment.bottomRight para
/// o avatar). Isso faz com que o offset do Positioned corresponda
/// diretamente à borda do círculo, mantendo a fórmula de centralização
/// exata.
class _ControlHitbox extends StatelessWidget {
  final double size;
  final Alignment alignment;
  final VoidCallback onTap;
  final Widget child;

  const _ControlHitbox({
    required this.size,
    required this.alignment,
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
        child: Align(alignment: alignment, child: child),
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
