import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/env.dart';
import '../../../core/http/client_factory.dart';
import '../data/bmo_chat_client.dart';

final httpClientProvider = Provider<http.Client>((ref) {
  return createHttpClient();
});

final bmoChatClientProvider = Provider<BmoChatClient>((ref) {
  return BmoChatClient(
    client: ref.watch(httpClientProvider),
    baseUrl: Env.bmoServerUrl,
  );
});
