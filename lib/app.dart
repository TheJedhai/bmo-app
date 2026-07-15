import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/identity/identity_provider.dart';
import 'core/identity/widgets/profile_selector.dart';
import 'core/theme/bmo_theme.dart';
import 'core/widgets/bmo_dock.dart';
import 'core/widgets/bmo_frame.dart';
import 'core/events/events_provider.dart';
import 'features/dashboard/presentation/dashboard_screen.dart';

class BmoApp extends ConsumerWidget {
  const BmoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'BMO',
      debugShowCheckedModeBanner: false,
      theme: BmoTheme.themeData,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('pt', 'BR'), Locale('en')],
      locale: const Locale('pt', 'BR'),
      home: const Scaffold(
        body: BmoFrame(
          child: _BmoShell(),
        ),
      ),
    );
  }
}

class _BmoShell extends ConsumerWidget {
  const _BmoShell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identityAsync = ref.watch(currentUserProvider);

    return identityAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: BmoColors.accentGreen),
      ),
      data: (user) {
        if (user == null) {
          // Sem perfil salvo → mostra seletor.
          return const ProfileSelector();
        }
        // Perfil ativo → principais features.
        return const _BmoMainShell();
      },
      error: (_, _) {
        // Falha ao carregar prefs → mostra seletor (usuário escolhe).
        return const ProfileSelector();
      },
    );
  }
}

/// Shell principal do app exibido quando há um perfil selecionado.
///
/// Extraído como widget separado para que o [eventsListenerProvider] só
/// seja primado quando há perfil — o SSE depende do X-User-Id no client.
///
/// A Dashboard é a raiz permanente. As demais telas são empurradas por
/// cima via [pushFeature] (definido em core/navigation/push_feature.dart).
class _BmoMainShell extends ConsumerWidget {
  const _BmoMainShell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(eventsListenerProvider); // Prime SSE com X-User-Id.

    return const Column(
      children: [
        Expanded(child: DashboardScreen()),
        BmoDock(),
      ],
    );
  }
}
