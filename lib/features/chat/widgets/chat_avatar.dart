import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/identity/identity_provider.dart';
import '../../../core/theme/bmo_theme.dart';
import '../data/chat_message.dart';

class ChatAvatar extends ConsumerWidget {
  final ChatRole role;
  final double size;

  const ChatAvatar({super.key, required this.role, this.size = 36});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    return _buildUserPlaceholder(ref);
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

  Widget _buildUserPlaceholder(WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final initial = currentUser?.initial ?? '?';

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
        initial,
        style: TextStyle(
          fontFamily: 'PressStart2P',
          color: BmoColors.textPrimary,
          fontSize: size * 0.4,
        ),
      ),
    );
  }
}
