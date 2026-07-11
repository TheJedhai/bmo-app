import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/identity/identity_provider.dart';
import 'features/chat/data/bmo_rich_registry.dart';
import 'features/chat/widgets/bmo_rich_image_card.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const BmoApp(),
    ),
  );
}
