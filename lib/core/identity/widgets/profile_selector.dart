import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/http/client_factory.dart';
import '../../../core/theme/bmo_theme.dart';
import '../data/users_client.dart';
import '../data/users_repository.dart';
import '../identity_provider.dart';
import '../user_profile.dart';
import 'profile_avatar.dart';

const _kMobileBreakpoint = 600.0;

// ============================================================
// Infra providers
// ============================================================

final usersClientProvider = Provider<UsersClient>((ref) {
  return UsersClient(
    client: ref.watch(httpClientProvider),
    baseUrl: Env.bmoServerUrl,
  );
});

final usersRepositoryProvider = Provider<UsersRepository>((ref) {
  return UsersRepository(ref.watch(usersClientProvider));
});

// ============================================================
// ProfileSelector
// ============================================================

/// Tela de seleção de perfil exibida dentro do [BmoFrame] quando não há
/// perfil salvo (primeira abertura ou após "trocar perfil").
///
/// Busca GET /api/v1/users e exibe a lista de perfis com avatar + nome.
/// Tap seleciona → persiste via [CurrentUser.setUser] → app carrega.
class ProfileSelector extends ConsumerStatefulWidget {
  const ProfileSelector({super.key});

  @override
  ConsumerState<ProfileSelector> createState() => _ProfileSelectorState();
}

class _ProfileSelectorState extends ConsumerState<ProfileSelector> {
  @override
  void initState() {
    super.initState();
  }

  Future<List<UserProfile>> _loadUsers() async {
    final repo = ref.read(usersRepositoryProvider);
    return repo.getUsers();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < _kMobileBreakpoint;

    return Scaffold(
      backgroundColor: BmoColors.screenBg,
      body: FutureBuilder<List<UserProfile>>(
        future: _loadUsers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: BmoColors.accentGreen),
            );
          }

          if (snapshot.hasError) {
            return _ErrorState(
              error: snapshot.error.toString(),
              onRetry: () => setState(() {}),
            );
          }

          final users = snapshot.data ?? const <UserProfile>[];

          if (users.isEmpty) {
            return _EmptyState(onRetry: () => setState(() {}));
          }

          return _ProfileList(
            users: users,
            isMobile: isMobile,
            onSelected: (user) {
              ref.read(currentUserProvider.notifier).setUser(user.id);
            },
          );
        },
      ),
    );
  }
}

// ============================================================
// Profile list layout
// ============================================================

class _ProfileList extends StatelessWidget {
  final List<UserProfile> users;
  final bool isMobile;
  final void Function(UserProfile) onSelected;

  const _ProfileList({
    required this.users,
    required this.isMobile,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 24 : 48,
          vertical: isMobile ? 32 : 48,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Text(
              'Quem está usando?',
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: isMobile ? 12 : 14,
                color: BmoColors.accentGreen,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: isMobile ? 24 : 32),

            // Profile cards
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: users.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final user = users[index];
                  return _ProfileCard(
                    user: user,
                    onTap: () => onSelected(user),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Profile card
// ============================================================

class _ProfileCard extends StatelessWidget {
  final UserProfile user;
  final VoidCallback onTap;

  const _ProfileCard({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: BmoColors.screenBgElevated,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              ProfileAvatar(profile: user, radius: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  user.name,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: BmoColors.textPrimary,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: BmoColors.textMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Error state
// ============================================================

class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off,
              color: Colors.redAccent,
              size: 40,
            ),
            const SizedBox(height: 12),
            const Text(
              'Não foi possível carregar os perfis',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: BmoColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              error,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: BmoColors.textMuted,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Empty state
// ============================================================

class _EmptyState extends StatelessWidget {
  final VoidCallback onRetry;

  const _EmptyState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_off,
              color: BmoColors.textMuted,
              size: 40,
            ),
            const SizedBox(height: 12),
            const Text(
              'Nenhum perfil encontrado',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: BmoColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            const Text(
              'Verifique se o bmo-server está rodando\ncom perfis configurados.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: BmoColors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}
