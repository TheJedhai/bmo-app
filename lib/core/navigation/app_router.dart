import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/chat/chat_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/home_devices/presentation/home_devices_screen.dart';
import '../../features/missions/presentation/missions_screen.dart';
import '../../features/rss/presentation/rss_screen.dart';
import '../../features/vault/presentation/vault_screen.dart';
import '../events/events_provider.dart';
import '../identity/identity_provider.dart';
import '../identity/widgets/profile_selector.dart';
import '../theme/bmo_theme.dart';
import '../widgets/bmo_dock.dart';
import '../widgets/bmo_frame.dart';

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
  const _AppShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identityAsync = ref.watch(currentUserProvider);
    ref.watch(eventsListenerProvider); // Prime SSE (guarded by identity inside).

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
        return BmoFrame(
          child: Column(
            children: [
              Expanded(child: child),
              const BmoDock(),
            ],
          ),
        );
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
/// ShellRoute (BmoFrame + BmoDock)
///   /           DashboardScreen
///   /chat       ChatScreen
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
      builder: (context, state, child) => _AppShell(child: child),
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
          pageBuilder: (context, state) =>
              _buildFeaturePage(const ChatScreen(), state),
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
          pageBuilder: (context, state) =>
              _buildFeaturePage(const RssScreen(), state),
        ),
        GoRoute(
          path: '/cofre',
          pageBuilder: (context, state) =>
              _buildFeaturePage(const VaultScreen(), state),
        ),
      ],
    ),
  ],
);
