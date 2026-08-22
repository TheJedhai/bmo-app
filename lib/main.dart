import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'core/identity/identity_provider.dart';
import 'core/platform/temp_orphan_sweep.dart';
import 'core/platform/url_strategy.dart';
import 'features/chat/data/bmo_rich_registry.dart';
import 'features/chat/widgets/bmo_rich_image_card.dart';
import 'features/chat/widgets/bmo_rich_question_card.dart';

void main() async {
  assert(
    Env.bmoServerUrl.startsWith('https://'),
    'BMO_SERVER_URL deve usar https:// (ATS no iOS bloqueia http) — recebido: '
    '${Env.bmoServerUrl}',
  );
  usePathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();

  // Varredura de temporários órfãos do BMO (nativo). Fire-and-forget: os
  // finally/dispose apagam no caso normal, mas morte do processo (crash,
  // force-quit, Jetsam) deixa `bmo_*` no NSTemporaryDirectory até o iOS
  // purgar. Não bloqueia o boot. Web: no-op.
  unawaited(sweepOrphanTempFiles());

  // Carrega SharedPreferences antes do app iniciar — o identity provider
  // depende dele para persistir/carregar o userId escolhido.
  //
  // Em ambientes sem secure context (ex.: HTTP sobre IP puro), getInstance() lança
  // exceção. O app inicializa sem storage nesse caso — o seletor de perfil
  // aparece e o fluxo segue normalmente.
  SharedPreferences? prefs;
  try {
    prefs = await SharedPreferences.getInstance();
  } catch (e) {
    debugPrint('SharedPreferences indisponível: $e');
  }

  BmoRichRegistry.register('image', (block) => BmoRichImageCard(block: block));
  BmoRichRegistry.register('question', (block) => BmoRichQuestionCard(block: block));
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const BmoApp(),
    ),
  );
}
