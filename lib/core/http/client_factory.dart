import 'package:http/http.dart' as http;

import 'client_factory_io.dart'
    if (dart.library.html) 'client_factory_web.dart' as impl;

/// Cria um http.Client adequado à plataforma:
/// - Web: FetchClient (Fetch API, suporta streaming SSE)
/// - IO (mobile/desktop): http.Client padrão
http.Client createHttpClient() => impl.createHttpClient();
