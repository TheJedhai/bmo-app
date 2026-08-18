/// Stub do vault para builds sem js_interop (iOS, Android, desktop).
///
/// Mesma API pública do [VaultScreen] real (const constructor, ConsumerWidget),
/// tela placeholder. NÃO importar nada de dentro de features/vault/ daqui —
/// qualquer import puxaria a árvore web-only de volta pro build.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/bmo_theme.dart';
import '../../core/widgets/bmo_back_button.dart';

/// Placeholder da aba Cofre em builds não-web.
class VaultScreen extends ConsumerWidget {
  const VaultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: BmoColors.screenBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const BmoBackButton(),
        title: Text(
          'Cofre',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 48, color: BmoColors.textMuted),
              const SizedBox(height: 16),
              Text(
                'Cofre disponível apenas na versão web',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
