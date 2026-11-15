import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/agent_chat/widgets/agent_chat_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/home_devices/presentation/home_devices_screen.dart';
import '../../features/missions/presentation/missions_screen.dart';
import '../../features/rss/presentation/rss_screen.dart';
import '../../features/calendar/presentation/calendar_screen.dart';
import '../../features/calendar/presentation/calendars_screen.dart';
import '../../features/coding/presentation/coding_project_screen.dart';
import '../../features/coding/presentation/coding_run_screen.dart';
import '../../features/coding/presentation/coding_screen.dart';
import '../../features/finances/presentation/finances_screen.dart';
import '../../features/vault/presentation/vault_screen.dart';
import '../events/events_provider.dart';
import '../identity/identity_provider.dart';
import '../identity/widgets/profile_selector.dart';
import '../theme/bmo_theme.dart';
import '../widgets/bmo_frame.dart';
import '../widgets/bmo_nav_bar.dart';
import '../widgets/bmo_top_bar.dart';

// ---------------------------------------------------------------------------
// Navigator keys
// ---------------------------------------------------------------------------

/// Navigator key for the root navigator — dialogs, modals, and anything that
/// should render *above* the BMO chassis use this navigator.
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Navigator key for the shell navigator — feature screens pushed/popped
/// inside the BMO chassis use this navigator.
final shellNavigatorKey = GlobalKey<NavigatorState>();

// ---------------------------------------------------------------------------
// Transition helpers
// ---------------------------------------------------------------------------

/// Fade transition matching the old [pushFeature] helper (200 ms).
///
/// Kept as a single function so that future animation upgrades (slide, zoom)
/// only touch this one site.
Page<void> _buildFeaturePage(Widget child, GoRouterState state) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
    transitionDuration: const Duration(milliseconds: 200),
  );
}

// ---------------------------------------------------------------------------
// Shell
// ---------------------------------------------------------------------------

/// Identity gate + BMO chassis used as the [ShellRoute] builder.
///
/// When no profile is selected the [child] (matched sub-route) is omitted
/// from the tree — go_router still instantiates it, but since it is never
/// mounted its providers are never subscribed.
class _AppShell extends ConsumerWidget {
  const _AppShell({required this.child, required this.currentLocation});

  final Widget child;
  final String currentLocation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identityAsync = ref.watch(currentUserProvider);
    ref.watch(
      eventsListenerProvider,
    ); // Prime SSE (guarded by identity inside).

    return identityAsync.when(
      loading: () => const BmoFrame(
        child: Center(
          child: CircularProgressIndicator(color: BmoColors.accentGreen),
        ),
      ),
      data: (user) {
        if (user == null) {
          return const BmoFrame(child: ProfileSelector());
        }
        final isDashboard = currentLocation == '/';
        final isMobile = MediaQuery.of(context).size.width < kMobileBreakpoint;

        Widget body;
        if (isMobile) {
          // Mobile: top bar em toda rota; nav bar só fora da dashboard.
          body = Stack(
            children: [
              Positioned(
                // Dashboard começa no topo (o header do relógio divide a
                // faixa com os controles); features mantêm o inset da barra.
                top: isDashboard ? 0 : BmoTopBar.totalTopInset,
                left: 0,
                right: 0,
                bottom: isDashboard ? 0 : BmoNavBar.totalBottomInset,
                child: child,
              ),
              BmoTopBar(),
              if (!isDashboard) BmoNavBar(currentLocation: currentLocation),
            ],
          );
        } else {
          // Desktop: controles sobre a faixa verde do frame; nav bar
          // só fora da dashboard.
          body = isDashboard
              ? child
              : Stack(
                  children: [
                    Positioned.fill(
                      bottom: BmoNavBar.totalBottomInset,
                      child: child,
                    ),
                    BmoNavBar(currentLocation: currentLocation),
                  ],
                );
        }
        return BmoFrame(child: body);
      },
      error: (_, _) => const BmoFrame(child: ProfileSelector()),
    );
  }
}

// ---------------------------------------------------------------------------
// Router
// ---------------------------------------------------------------------------

/// Top-level [GoRouter] instance wired to [MaterialApp.router].
///
/// Route tree:
/// ```
/// ShellRoute (BmoFrame)
///   /           DashboardScreen
///   /chat       AgentChatScreen (chat v2)
///   /missoes    MissionsScreen
///   /casa       HomeDevicesScreen
///   /noticias   RssScreen
///   /cofre      VaultScreen
/// ```
final appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/',
  routes: [
    ShellRoute(
      navigatorKey: shellNavigatorKey,
      builder: (context, state, child) =>
          _AppShell(currentLocation: state.uri.path, child: child),
      routes: [
        GoRoute(
          path: '/',
          pageBuilder: (context, state) => NoTransitionPage<void>(
            key: state.pageKey,
            child: const DashboardScreen(),
          ),
        ),
        GoRoute(
          path: '/chat',
          pageBuilder: (context, state) {
            // Conversas de um projeto: `/chat?project=<id>` (mesmo padrão de
            // `/noticias?article=`). Sem id = chat principal.
            final projectId =
                int.tryParse(state.uri.queryParameters['project'] ?? '');
            return _buildFeaturePage(
              AgentChatScreen(projectId: projectId),
              state,
            );
          },
        ),
        GoRoute(
          path: '/missoes',
          pageBuilder: (context, state) =>
              _buildFeaturePage(const MissionsScreen(), state),
        ),
        GoRoute(
          path: '/casa',
          pageBuilder: (context, state) =>
              _buildFeaturePage(const HomeDevicesScreen(), state),
        ),
        GoRoute(
          path: '/noticias',
          pageBuilder: (context, state) {
            // Deep link vindo do card: /noticias?article=<id> abre o modal
            // do artigo. Sem id (link puro ou id inválido) = lista normal.
            final articleId =
                int.tryParse(state.uri.queryParameters['article'] ?? '');
            return _buildFeaturePage(RssScreen(articleId: articleId), state);
          },
        ),
        GoRoute(
          path: '/cofre',
          pageBuilder: (context, state) =>
              _buildFeaturePage(const VaultScreen(), state),
        ),
        GoRoute(
          path: '/calendario',
          pageBuilder: (context, state) =>
              _buildFeaturePage(const CalendarScreen(), state),
        ),
        GoRoute(
          path: '/calendarios',
          pageBuilder: (context, state) =>
              _buildFeaturePage(const CalendarsScreen(), state),
        ),
        GoRoute(
          path: '/financas',
          pageBuilder: (context, state) =>
              _buildFeaturePage(const FinancesScreen(), state),
        ),
        GoRoute(
          path: '/coding',
          pageBuilder: (context, state) =>
              _buildFeaturePage(const CodingScreen(), state),
        ),
        // Antes de `/coding/:projectId` para o segmento "runs" nunca ser lido
        // como id de projeto.
        GoRoute(
          path: '/coding/runs/:runId',
          pageBuilder: (context, state) {
            final runId = int.tryParse(state.pathParameters['runId'] ?? '');
            return _buildFeaturePage(
              runId == null
                  ? const CodingScreen()
                  : CodingRunScreen(runId: runId),
              state,
            );
          },
        ),
        GoRoute(
          path: '/coding/:projectId',
          pageBuilder: (context, state) {
            final projectId =
                int.tryParse(state.pathParameters['projectId'] ?? '');
            return _buildFeaturePage(
              projectId == null
                  ? const CodingScreen()
                  : CodingProjectScreen(projectId: projectId),
              state,
            );
          },
        ),
      ],
    ),
  ],
);
