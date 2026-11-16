// Ordem dos cards dentro de uma mensagem: aprovação antes do bloco rico que a
// ferramenta aprovada gerou (o servidor manda tool → rich → approval).
//
// Run:
//   flutter test test/agent_chat/agent_message_order_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bmo_app/features/agent_chat/data/agent_message.dart';
import 'package:bmo_app/features/agent_chat/widgets/agent_message_list.dart';
import 'package:bmo_app/features/agent_chat/widgets/agent_part_widgets.dart';
import 'package:bmo_app/features/rich_blocks/data/bmo_rich_registry.dart';

AgentMessage _message() => const AgentMessage(
      id: 'm1',
      role: AgentRole.assistant,
      parts: [
        AgentTextPart('vou rodar'),
        AgentToolPart(
          callId: 'c1',
          name: 'run_coding_task',
          label: 'Rodar',
          status: AgentToolStatus.ok,
        ),
        AgentRichPart(
          blockId: 'coding-run-7',
          richType: 'image',
          payload: {'image_id': 1},
          mutable: true,
        ),
        AgentApprovalPart(
          callId: 'c2',
          tool: 'merge_coding_run',
          label: 'Juntar run na base',
          summary: 'Juntar bmo/run-7 em main',
          decision: AgentApprovalDecision.pending,
        ),
      ],
    );

void main() {
  setUp(() {
    BmoRichRegistry.reset();
    BmoRichRegistry.register(
      'image',
      (block) => Container(
        key: const ValueKey('rich-card'),
        height: 40,
        color: const Color(0xFF222222),
        child: const Text('bloco rico'),
      ),
    );
  });

  tearDown(BmoRichRegistry.reset);

  testWidgets('aprovação aparece antes do bloco rico', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AgentMessageList(
          messages: [_message()],
          onApprove: (_) {},
          onDeny: (_, _) {},
        ),
      ),
    ));

    expect(find.byType(AgentApprovalCard), findsOneWidget);
    expect(find.text('bloco rico'), findsOneWidget);

    final approvalY = tester.getTopLeft(find.byType(AgentApprovalCard)).dy;
    final richY = tester.getTopLeft(find.text('bloco rico')).dy;
    expect(approvalY, lessThan(richY));
  });
}
