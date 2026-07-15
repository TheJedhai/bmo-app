import 'package:flutter/material.dart';

/// Card de atalho para o Cofre (E2E zero-knowledge).
///
/// Por decisão consciente de segurança, NÃO exibe conteúdo nem contagem
/// de itens — isso vazaria informação. Mostra apenas um ícone de cadeado
/// grande em outline na cor do accent, centralizado.
/// Toque via DashCard onTap → context.push('/cofre').
class VaultCard extends StatelessWidget {
  const VaultCard({super.key, required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Icon(
          Icons.lock_outline,
          size: 48,
          color: accent,
        ),
      ),
    );
  }
}
