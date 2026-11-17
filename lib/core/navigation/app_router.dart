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
import '../../features/coding/presentation/coding_project_settings_screen.dart';
import '../../features/coding/presentation/coding_run_screen.dart';
import '../../features/coding/presentation/coding_task_screen.dart';
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

/// Redireciona o link antigo `/chat?project=N` para a área do projeto.
///
/// Conversa de projeto não mora mais no Chat: `/coding/N/chat`. Mantém links
/// antigos (bookmark, notificação, card velho) funcionando.
String? redirectLegacyProjectChat(BuildContext context, GoRouterState state) {
  if (state.uri.path != '/chat') return null;
  final projectId = int.tryParse(state.uri.queryParameters['project'] ?? '');
  if (projectId == null) return null;
  return '/coding/$projectId/chat';
}

/// Memórias saíram de feature própria: `/memorias` agora mora no chat como
/// modal. Link antigo (bookmark) volta para a raiz em vez de erro de rota.
String? redirectLegacyMemories(BuildContext context, GoRouterState state) {
  if (state.uri.path == '/memorias') return '/';
  return null;
}

/// Rotas internas do [ShellRoute] (o chassis BMO fica no [appRouter]).
///
/// Públicas para os testes de navegação montarem um router enxuto com a
/// mesma tabela de rotas, sem o shell/identidade.
///
/// ```
/// /                      DashboardScreen
/// /chat                  AgentChatScreen — só chat principal
/// /missoes               MissionsScreen
/// /casa                  HomeDevicesScreen
/// /noticias              RssScreen
/// /cofre                 VaultScreen
/// /calendario            CalendarScreen
/// /calendarios           CalendarsScreen
/// /financas              FinancesScreen
/// /coding                CodingScreen
/// /coding/runs/:runId    CodingRunScreen
/// /coding/tasks/:taskId  CodingTaskScreen
/// /coding/:projectId/chat  AgentChatScreen do projeto
/// /coding/:projectId     CodingProjectScreen
/// /coding/:projectId/settings  CodingProjectSettingsScreen
/// ```
final List<RouteBase> appRoutes = [
  GoRoute(
    path: '/',
    pageBuilder: (context, state) => NoTransitionPage<void>(
      key: state.pageKey,
      child: const DashboardScreen(),
    ),
  ),
  GoRoute(
    path: '/chat',
    pageBuilder: (context, state) =>
        _buildFeaturePage(const AgentChatScreen(), state),
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
        runId == null ? const CodingScreen() : CodingRunScreen(runId: runId),
        state,
      );
    },
  ),
  // Detalhe da tarefa: antes de `/coding/:projectId` para "tasks" nunca ser
  // lido como id de projeto.
  GoRoute(
    path: '/coding/tasks/:taskId',
    pageBuilder: (context, state) {
      final taskId = int.tryParse(state.pathParameters['taskId'] ?? '');
      return _buildFeaturePage(
        taskId == null ? const CodingScreen() : CodingTaskScreen(taskId: taskId),
        state,
      );
    },
  ),
  // Configurações do projeto: antes de `/coding/:projectId` para "settings"
  // nunca ser lido como id.
  GoRoute(
    path: '/coding/:projectId/settings',
    pageBuilder: (context, state) {
      final projectId =
          int.tryParse(state.pathParameters['projectId'] ?? '');
      return _buildFeaturePage(
        projectId == null
            ? const CodingScreen()
            : CodingProjectSettingsScreen(projectId: projectId),
        state,
      );
    },
  ),
  // Conversa de projeto vive dentro de Coding, não no Chat.
  GoRoute(
    path: '/coding/:projectId/chat',
    pageBuilder: (context, state) {
      final projectId =
          int.tryParse(state.pathParameters['projectId'] ?? '');
      return _buildFeaturePage(
        projectId == null
            ? const CodingScreen()
            : AgentChatScreen(projectId: projectId),
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
];

/// Top-level [GoRouter] instance wired to [MaterialApp.router].
final appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/',
  redirect: (context, state) =>
      redirectLegacyMemories(context, state) ??
      redirectLegacyProjectChat(context, state),
  routes: [
    ShellRoute(
      navigatorKey: shellNavigatorKey,
      builder: (context, state, child) =>
          _AppShell(currentLocation: state.uri.path, child: child),
      routes: appRoutes,
    ),
  ],
);
