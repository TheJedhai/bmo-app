import 'package:flutter/material.dart';

import '../../../../core/theme/bmo_theme.dart';

/// Rótulo e cor de um status de plano (`active|exhausted|cancelled`).
/// Valor fora do contrato aparece cru.
({String label, Color color}) planStatusLook(String status) => switch (status) {
      'active' => (label: 'ativo', color: BmoColors.accentGreen),
      'exhausted' => (label: 'orçamento esgotado', color: BmoColors.accentRed),
      'cancelled' => (label: 'cancelado', color: BmoColors.textMuted),
      _ => (label: status, color: BmoColors.textSecondary),
    };

/// "US$ 1.25" — dinheiro com 2 casas.
String formatMoney(double usd) => 'US\$ ${usd.toStringAsFixed(2)}';
