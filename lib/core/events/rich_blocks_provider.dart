import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../config/env.dart';
import '../http/client_factory.dart';
import 'rich_blocks_state.dart';

part 'rich_blocks_provider.g.dart';

/// Notifier that holds live state for every rich block currently on screen.
///
/// Keyed by [BmoRichBlock.blockId].  When a `rich.update` SSE event arrives,
/// [_applyPatch] mutates the entry in-place so only the corresponding card
/// rebuilds — no full-screen flicker.
///
/// Generic: image blocks today, question/CC blocks later.
@riverpod
class RichBlocks extends _$RichBlocks {
  @override
  Map<String, RichBlockState> build() {
    return {};
  }

  /// Applies a `rich.update` SSE patch to one block.
  ///
  /// [blockId] comes from the event envelope; [patch] is the nested `patch`
  /// object (e.g. `{"status":"generating","progress":50}`).
  void applyPatch(String blockId, Map<String, dynamic> patch) {
    final current = Map<String, RichBlockState>.from(state);
    final existing = current[blockId];
    final newState = RichBlockState.fromPatch(
      patch,
      existingImageId: existing?.imageId,
    );
    // Carry forward image_id from payload when SSE doesn't include it.
    final mergedImageId = newState.imageId != null && newState.imageId! > 0
        ? newState.imageId
        : existing?.imageId;
    // Carry forward chosen_value when SSE doesn't include it.
    final mergedChosenValue = newState.chosenValue ?? existing?.chosenValue;
    state = {
      ...current,
      blockId: RichBlockState(
        status: newState.status,
        progress: newState.progress,
        imageId: mergedImageId,
        error: newState.error,
        chosenValue: mergedChosenValue,
      ),
    };
  }

  /// One-shot sync from the REST API.
  ///
  /// Used by cards on mount and after SSE reconnect to heal any state lost
  /// during disconnection.  GETs `/api/v1/images/{imageId}` and upserts the
  /// result into the map under [blockId].
  Future<void> syncImageBlock(String blockId, int imageId) async {
    final client = ref.read(httpClientProvider);
    try {
      final url = Uri.parse(
        '${Env.bmoServerUrl}/api/v1/images/$imageId',
      );
      final response = await client.get(url);
      if (response.statusCode != 200) return;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final current = Map<String, RichBlockState>.from(state);
      state = {
        ...current,
        blockId: RichBlockState.fromPatch(json, existingImageId: imageId),
      };
    } catch (_) {
      // Best-effort — if the GET fails (network, etc.) the card still has the
      // last known SSE state or its static fallback.
    }
  }

  /// One-shot sync of a question block from the REST API.
  ///
  /// GETs `/api/v1/questions/{questionId}` and upserts the result into the
  /// map under [blockId].  The response fields (`status`, `chosen_value`) are
  /// parsed by [RichBlockState.fromPatch].
  Future<void> syncQuestionBlock(String blockId, int questionId) async {
    final client = ref.read(httpClientProvider);
    try {
      final url = Uri.parse(
        '${Env.bmoServerUrl}/api/v1/questions/$questionId',
      );
      final response = await client.get(url);
      if (response.statusCode != 200) return;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final current = Map<String, RichBlockState>.from(state);
      state = {
        ...current,
        blockId: RichBlockState.fromPatch(json),
      };
    } catch (_) {
      // Best-effort — same as syncImageBlock.
    }
  }
}
