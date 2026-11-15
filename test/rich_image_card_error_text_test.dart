// Card rico de imagem: erro longo fica contido no card (3 linhas +
// reticências) e o texto completo abre num diálogo selecionável.
//
// Run:
//   flutter test test/rich_image_card_error_text_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bmo_app/core/events/rich_blocks_provider.dart';
import 'package:bmo_app/core/events/rich_blocks_state.dart';
import 'package:bmo_app/features/chat/data/bmo_rich_block.dart';
import 'package:bmo_app/features/chat/widgets/bmo_clamped_text.dart';
import 'package:bmo_app/features/chat/widgets/bmo_rich_image_card.dart';

class FakeRichBlocks extends RichBlocks {
  FakeRichBlocks(this.initial);

  final Map<String, RichBlockState> initial;

  @override
  Map<String, RichBlockState> build() => initial;
}

final _longError = [
  for (var i = 1; i <= 40; i++) 'linha $i do erro',
].join('\n');

void main() {
  testWidgets('erro de 40 linhas fica contido no card e abre no toque',
      (tester) async {
    const block = BmoRichBlock(
      v: 2,
      type: 'image',
      blockId: 'image-1',
      payload: {},
      mutable: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          richBlocksProvider.overrideWith(
            () => FakeRichBlocks({
              'image-1': RichBlockState(
                status: RichBlockStatus.failed,
                error: _longError,
              ),
            }),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: BmoRichImageCard(block: block)),
        ),
      ),
    );
    // Post-frame callback do sync inicial.
    await tester.pump();

    expect(tester.takeException(), isNull);

    // Altura do card limitada a 120 + padding vertical de 4 de cada lado.
    expect(
      tester.getSize(find.byType(BmoRichImageCard)).height,
      lessThanOrEqualTo(128),
    );

    final text = tester.widget<Text>(
      find.descendant(
        of: find.byType(BmoClampedText),
        matching: find.byType(Text),
      ),
    );
    expect(text.maxLines, 3);
    expect(text.overflow, TextOverflow.ellipsis);

    // O texto não pode passar da borda do card.
    final cardRect = tester.getRect(find.byType(BmoRichImageCard));
    final textRect = tester.getRect(find.byType(BmoClampedText));
    expect(cardRect.contains(textRect.topLeft), isTrue);
    expect(cardRect.contains(textRect.bottomRight), isTrue);

    await tester.tap(find.byType(BmoClampedText));
    await tester.pumpAndSettle();

    final dialogText = tester.widget<SelectableText>(
      find.byType(SelectableText),
    );
    expect(dialogText.data, _longError);
  });
}
