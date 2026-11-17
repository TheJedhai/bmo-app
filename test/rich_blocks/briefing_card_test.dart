// Bloco rico `briefing`: seções na ordem do payload (missões primeiro) e
// `speech` não renderizado.
//
// Run:
//   flutter test test/rich_blocks/briefing_card_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bmo_app/core/theme/bmo_theme.dart';
import 'package:bmo_app/features/rich_blocks/data/bmo_rich_block.dart';
import 'package:bmo_app/features/rich_blocks/widgets/bmo_rich_briefing_card.dart';

void main() {
  testWidgets('renderiza seções na ordem do payload e ignora speech', (
    tester,
  ) async {
    const block = BmoRichBlock(
      v: 2,
      type: 'briefing',
      blockId: 'briefing-1',
      mutable: false,
      speech: 'Bom dia. Duas missões, tempo estável.',
      payload: {
        'sections': [
          {
            'key': 'missions',
            'title': 'Missões de hoje',
            'lines': ['17/11 — Pagar luz'],
          },
          {
            'key': 'weather',
            'title': 'Tempo',
            'lines': ['Brasília: 19° a 30°, chuva 20%'],
          },
        ],
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: BmoTheme.themeData,
        home: const Scaffold(body: BmoRichBriefingCard(block: block)),
      ),
    );

    expect(find.text('Missões de hoje'), findsOneWidget);
    expect(find.text('17/11 — Pagar luz'), findsOneWidget);
    expect(find.text('Tempo'), findsOneWidget);
    expect(find.text('Brasília: 19° a 30°, chuva 20%'), findsOneWidget);
    expect(find.textContaining('Duas missões'), findsNothing);

    final missionsY = tester.getTopLeft(find.text('Missões de hoje')).dy;
    final weatherY = tester.getTopLeft(find.text('Tempo')).dy;
    expect(missionsY, lessThan(weatherY));
  });
}
