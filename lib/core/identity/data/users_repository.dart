import '../user_profile.dart';
import 'users_client.dart';

/// Thin wrapper sobre [UsersClient].
///
/// Existe para manter a arquitetura consistente — feature clients nunca são
/// chamados diretamente de providers/widgets. Se caching ou offline support
/// forem adicionados no futuro, o ponto de extensão já está aqui.
class UsersRepository {
  final UsersClient _client;

  UsersRepository(this._client);

  Future<List<UserProfile>> getUsers() => _client.getUsers();
}
