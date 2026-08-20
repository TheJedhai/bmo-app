/// Configuração de ambiente lida via --dart-define no build/run.
class Env {
  static const qwenpawUrl = String.fromEnvironment(
    'QWENPAW_URL',
    defaultValue: 'http://localhost:8088',
  );

  static const bmoServerUrl = String.fromEnvironment(
    'BMO_SERVER_URL',
    // Hostname Tailscale com HTTPS via Caddy — obrigatório para o ATS no iOS.
    defaultValue: 'https://jedhais-mac-mini.taild5baed.ts.net',
  );

  static const agentId = String.fromEnvironment(
    'AGENT_ID',
    defaultValue: 'default',
  );
}
