import 'package:flutter/material.dart';

import '../../theme/bmo_theme.dart';
import '../user_profile.dart';

/// Avatar circular com a inicial do nome do perfil.
///
/// Usado no seletor de perfil e no botão de troca dentro de settings.
/// O tamanho padrão é 48px; use [radius] para ajustar.
class ProfileAvatar extends StatelessWidget {
  final UserProfile profile;
  final double radius;

  const ProfileAvatar({
    super.key,
    required this.profile,
    this.radius = 24,
  });

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: BmoColors.accentGreen.withValues(alpha: 0.2),
      child: Text(
        profile.initial,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: radius * 0.7,
          fontWeight: FontWeight.w600,
          color: BmoColors.accentGreen,
        ),
      ),
    );
  }
}
