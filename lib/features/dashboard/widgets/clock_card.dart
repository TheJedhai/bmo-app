import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/identity/identity_provider.dart';
import '../../../core/theme/bmo_theme.dart';

/// Relógio + data + saudação.
///
/// Span 2×1 no grid da dashboard. Atualiza a hora a cada minuto e mostra
/// a data por extenso em pt-BR com saudação por período do dia + nome do
/// usuário atual.
class ClockCard extends ConsumerStatefulWidget {
  const ClockCard({super.key, required this.accent});

  final Color accent;

  @override
  ConsumerState<ClockCard> createState() => _ClockCardState();
}

class _ClockCardState extends ConsumerState<ClockCard> {
  Timer? _timer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(
      const Duration(minutes: 1),
      (_) {
        setState(() {
          _now = DateTime.now();
        });
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _greeting(int hour) {
    if (hour >= 6 && hour < 12) return 'Bom dia,';
    if (hour >= 12 && hour < 18) return 'Boa tarde,';
    return 'Boa noite,';
  }

  @override
  Widget build(BuildContext context) {
    final hourFormat = DateFormat('HH:mm');
    final dateFormat = DateFormat.yMMMMEEEEd('pt_BR');
    final hour = _now.hour;

    final userAsync = ref.watch(currentUserProvider);
    final userName = userAsync.whenOrNull(data: (u) => u?.name) ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hora atual
        Text(
          hourFormat.format(_now),
          style: const TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 32,
            color: BmoColors.accentGreen,
          ),
        ),
        const SizedBox(height: 8),
        // Data por extenso
        Text(
          dateFormat.format(_now),
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            color: BmoColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        // Saudação + nome
        Text(
          '${_greeting(hour)} $userName',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            color: BmoColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
