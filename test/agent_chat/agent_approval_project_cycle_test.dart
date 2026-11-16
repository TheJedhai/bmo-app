// Cartões de aprovação dos tools do ciclo de projeto
// (propose_coding_plan, merge_coding_run, continue_coding_run): nenhum
// layout novo — label e summary vêm prontos do servidor.
//
// Run:
//   flutter test test/agent_chat/agent_approval_project_cycle_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bmo_app/features/agent_chat/data/agent_message.dart';
import 'package:bmo_app/features/agent_chat/widgets/agent_message_list.dart';

const _labels = {
  'propose_coding_plan': 'Propor plano de coding',
  'merge_coding_run': 'Juntar run na base',
  'continue_coding_run': 'Continuar o run',
};

const _summaries = {
  'propose_coding_plan': 'Plano com 5 runs, até US\$ 10.00',
  'merge_coding_run': 'Juntar bmo/run-7 em main',
  'continue_coding_run': 'Continuar o run #7 com a correção',
};

AgentMessage _messageWith(Set<String> tools) => AgentMessage(
      id: 'm1',
      role: AgentRole.assistant,
      parts: [
        for (final tool in tools)
          AgentApprovalPart(
            callId: 'call-$tool',
            tool: tool,
            label: _labels[tool]!,
            summary: _summaries[tool]!,
            decision: AgentApprovalDecision.pending,
          ),
      ],
    );

void main() {
  for (final tool in _labels.keys) {
    testWidgets('$tool mostra label e summary do servidor', (tester) async {
      String? approved;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AgentMessageList(
            messages: [_messageWith({tool})],
            onApprove: (callId) => approved = callId,
            onDeny: (_, _) {},
          ),
        ),
      ));

      expect(find.text(_labels[tool]!), findsOneWidget);
      expect(find.text(_summaries[tool]!), findsOneWidget);
      expect(find.text('Aprovar'), findsOneWidget);
      expect(find.text('Negar'), findsOneWidget);

      await tester.tap(find.text('Aprovar'));
      expect(approved, 'call-$tool');
    });
  }

  testWidgets('os três cartões convivem na mesma mensagem', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AgentMessageList(
          messages: [_messageWith(_labels.keys.toSet())],
          onApprove: (_) {},
          onDeny: (_, _) {},
        ),
      ),
    ));

    for (final label in _labels.values) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Aprovar'), findsNWidgets(3));
  });
}
