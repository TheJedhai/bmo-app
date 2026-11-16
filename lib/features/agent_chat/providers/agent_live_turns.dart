import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/events/events_provider.dart';

part 'agent_live_turns.g.dart';

/// Turnos de chat vistos no SSE global (`/api/v1/stream`), targeted ao
/// usuário: `session.turn_started` e `session.turn_completed`.
///
/// Serve a conversa aberta: turno de outro cliente vira "BMO respondendo" e o
/// `turn_completed` dispara o refetch. A novidade da lista é do servidor
/// (`unread` em `GET /api/v2/sessions`), não daqui.
class AgentLiveTurnsState {
  /// Sessões com turno em andamento: `session_id -> turn_id`.
  final Map<String, String?> active;

  /// Último turno concluído por sessão (pulso para o refetch da conversa).
  final Map<String, String> completed;

  const AgentLiveTurnsState({this.active = const {}, this.completed = const {}});

  /// Turno rodando nesta sessão (`null` = nenhum).
  String? activeTurnOf(String sessionId) => active[sessionId];

}

@riverpod
class AgentLiveTurns extends _$AgentLiveTurns {
  @override
  AgentLiveTurnsState build() {
    ref.listen<AsyncValue<Map<String, dynamic>>>(eventsStreamProvider, (
      previous,
      next,
    ) {
      final event = next.valueOrNull;
      if (event != null) _onEvent(event);
    });
    return const AgentLiveTurnsState();
  }

  void _onEvent(Map<String, dynamic> event) {
    final sessionId = event['session_id'];
    if (sessionId is! String) return;
    final turnId = event['turn_id'];

    switch (event['type']) {
      case 'session.turn_started':
        state = AgentLiveTurnsState(
          active: {
            ...state.active,
            sessionId: turnId is String ? turnId : null,
          },
          completed: state.completed,
        );
      case 'session.turn_completed':
        final active = {...state.active}..remove(sessionId);
        state = AgentLiveTurnsState(
          active: active,
          completed: {
            ...state.completed,
            if (turnId is String) sessionId: turnId,
          },
        );
    }
  }
}
