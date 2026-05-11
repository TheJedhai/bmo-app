import 'package:flutter/material.dart';

import '../../../core/theme/bmo_theme.dart';
import '../data/chat_message.dart';

class ChatAvatar extends StatelessWidget {
  final ChatRole role;
  final double size;

  const ChatAvatar({super.key, required this.role, this.size = 36});

  @override
  Widget build(BuildContext context) {
    if (role == ChatRole.assistant) {
      return ClipOval(
        child: Image.asset(
          'assets/avatars/bmo.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _buildBmoFallback(),
        ),
      );
    }
    return _buildUserPlaceholder();
  }

  Widget _buildBmoFallback() {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: BmoColors.bodyGreen,
        shape: BoxShape.circle,
      ),
      child: Text(
        'B',
        style: TextStyle(
          fontFamily: 'PressStart2P',
          color: Colors.white,
          fontSize: size * 0.4,
        ),
      ),
    );
  }

  Widget _buildUserPlaceholder() {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: BmoColors.screenBgElevated,
        shape: BoxShape.circle,
        border: Border.all(color: BmoColors.textMuted, width: 1),
      ),
      child: Text(
        'J',
        style: TextStyle(
          fontFamily: 'PressStart2P',
          color: BmoColors.textPrimary,
          fontSize: size * 0.4,
        ),
      ),
    );
  }
}
