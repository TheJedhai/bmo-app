import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/env.dart';
import '../http/client_factory.dart';
import 'identity_state.dart';
import 'user_profile.dart';

part 'identity_provider.g.dart';

// ============================================================
// Keys
// ============================================================

const _kUserIdKey = 'current_user_id';

// ============================================================
// MeClient — GET /api/v1/me
// ============================================================

/// Cliente mínimo para validar o perfil salvo via GET /api/v1/me.
///
/// Diferente dos outros clients, este envia X-User-Id manualmente porque
/// é ele que abastece o [currentUserIdProvider] — há uma dependência
/// circular se passar pelo [BmoHttpClient] antes do userId estar definido.
class MeClient {
  final http.Client _client;
  final String _baseUrl;

  MeClient({required http.Client client, required String baseUrl})
      : _client = client,
        _baseUrl = baseUrl;

  /// GET /api/v1/me → {user: {id, name}, features: [...]}.
  ///
  /// Envia [userId] como header X-User-Id.
  /// Retorna [MeResponse] com user e lista de feature keys.
  /// Lança [MeException] se o servidor retornar erro.
  Future<MeResponse> getMe(String userId) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/api/v1/me'),
      headers: {'X-User-Id': userId},
    );

    if (response.statusCode == 400) {
      final body = _tryDecode(response.body);
      if (body is Map<String, dynamic> &&
          body['error'] == 'unknown_user') {
        throw MeUnknownUserException();
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MeException(response.statusCode, response.body);
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final userJson = decoded['user'] as Map<String, dynamic>?;
    if (userJson == null) {
      throw MeException(response.statusCode, 'missing "user" field');
    }

    final features = (decoded['features'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];

    return MeResponse(
      user: UserProfile.fromJson(userJson),
      features: features,
    );
  }

  dynamic _tryDecode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }
}

class MeResponse {
  final UserProfile user;
  final List<String> features;

  const MeResponse({required this.user, required this.features});
}

class MeException implements Exception {
  final int statusCode;
  final String body;
  const MeException(this.statusCode, this.body);

  @override
  String toString() => 'MeException($statusCode): $body';
}

class MeUnknownUserException implements Exception {
  const MeUnknownUserException();

  @override
  String toString() => 'MeUnknownUserException: unknown_user';
}

// ============================================================
// Infra providers
// ============================================================

final meClientProvider = Provider<MeClient>((ref) {
  return MeClient(
    client: createHttpClient(),
    baseUrl: Env.bmoServerUrl,
  );
});

/// Provider de SharedPreferences — setado em main.dart antes do runApp.
///
/// O app depende dele para carregar/salvar o userId. Widgets que precisam
/// de SharedPreferences devem usar este provider.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Setado em main.dart antes do runApp');
});

// ============================================================
// CurrentUser — @riverpod notifier
// ============================================================

@riverpod
class CurrentUser extends _$CurrentUser {
  @override
  Future<UserProfile?> build() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final savedId = prefs.getInt(_kUserIdKey);

    if (savedId == null) {
      // Primeira abertura — sem perfil salvo.
      return null;
    }

    // Valida o perfil salvo no servidor.
    final client = ref.read(meClientProvider);
    try {
      final me = await client.getMe(savedId.toString());
      // Perfil válido — espelha no provider síncrono e nas features.
      ref.read(currentUserIdProvider.notifier).state = savedId;
      ref.read(enabledFeaturesProvider.notifier).state =
          me.features.toSet();
      return me.user;
    } on MeUnknownUserException {
      // Perfil salvo não existe mais no servidor — limpa.
      await prefs.remove(_kUserIdKey);
      return null;
    } catch (_) {
      // Erro de rede ou servidor — mantém o perfil salvo mas não
      // bloqueia o app. Retorna um perfil mínimo com o id que temos.
      ref.read(currentUserIdProvider.notifier).state = savedId;
      return UserProfile(id: savedId, name: savedId.toString());
    }
  }

  /// Seleciona um perfil, persiste, e atualiza o estado global.
  Future<void> setUser(int userId) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt(_kUserIdKey, userId);
    ref.read(currentUserIdProvider.notifier).state = userId;

    // Valida e popula features.
    final client = ref.read(meClientProvider);
    try {
      final me = await client.getMe(userId.toString());
      ref.read(enabledFeaturesProvider.notifier).state =
          me.features.toSet();
      state = AsyncData(me.user);
    } on MeUnknownUserException {
      // Não deveria acontecer logo após selecionar da lista, mas
      // trata limpando.
      await prefs.remove(_kUserIdKey);
      ref.read(currentUserIdProvider.notifier).state = null;
      state = const AsyncData(null);
    } catch (_) {
      // Rede falhou — usa fallback mínimo.
      state = AsyncData(UserProfile(id: userId, name: userId.toString()));
    }
  }

  /// Remove o perfil salvo e volta ao estado "sem perfil".
  Future<void> clearUser() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.remove(_kUserIdKey);
    ref.read(currentUserIdProvider.notifier).state = null;
    ref.read(enabledFeaturesProvider.notifier).state = const {};
    state = const AsyncData(null);
  }
}
