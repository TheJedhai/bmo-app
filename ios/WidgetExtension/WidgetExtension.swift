import WidgetKit
import SwiftUI
import AppIntents
import os

// Logger da extensão — subsystem fixo p/ filtrar no simulador:
//   xcrun simctl spawn booted log stream --predicate 'subsystem == "com.jedhai.bmoApp.widget"'
private let widgetLog = Logger(subsystem: "com.jedhai.bmoApp.widget", category: "lights")

// Configuração estática — identidade por configuração (mesmo padrão do MCP:
// o cliente não escolhe, vem embutido).
enum WidgetConfig {
    static let baseUrl = "https://jedhais-mac-mini.taild5baed.ts.net"
    static let userId = "1" // Jedhai
    static let lightsPath = "/api/v1/widget/lights"
    static let refreshMinutes = 15
}

let LightWidgetKind = "LightsWidget"

// Envelope: { kind, generated_at, total_count, summary: { on_count, total }, items: [...] }
struct LightsResponse: Decodable {
    let generatedAt: String
    let summary: Summary
    let items: [LightItem]

    enum CodingKeys: String, CodingKey {
        case generatedAt = "generated_at"
        case summary
        case items
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        generatedAt = try c.decode(String.self, forKey: .generatedAt)
        summary = try c.decode(Summary.self, forKey: .summary)
        items = (try? c.decode([LightItem].self, forKey: .items)) ?? []
    }

    init(generatedAt: String, summary: Summary, items: [LightItem]) {
        self.generatedAt = generatedAt
        self.summary = summary
        self.items = items
    }

    struct Summary: Decodable {
        let onCount: Int
        let total: Int

        enum CodingKeys: String, CodingKey {
            case onCount = "on_count"
            case total
        }
    }
}

// Item tolerante: `state` vem como { state: "ON" } | "ON" | "on" | bool.
struct LightItem: Decodable {
    let name: String
    let isOn: Bool

    // Servidor manda a chave "light", não "name" — era isso que deixava o nome
    // vazio (fallback ?? "") e quebrava o POST (/api/v1/lights//on).
    enum CodingKeys: String, CodingKey { case name = "light", state }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        // Payload real manda "state": "OFF" (String simples): o ramo bool não
        // decodifica, cai no de String -> isOn = "OFF".uppercased() == "ON".
        if let b = try? c.decodeIfPresent(Bool.self, forKey: .state) {
            isOn = b
        } else if let s = try? c.decodeIfPresent(String.self, forKey: .state) {
            isOn = s.uppercased() == "ON"
        } else if let obj = try? c.decodeIfPresent(StateObj.self, forKey: .state) {
            isOn = obj.state.uppercased() == "ON"
        } else {
            isOn = false
        }
    }

    init(name: String, isOn: Bool) {
        self.name = name
        self.isOn = isOn
    }

    struct StateObj: Decodable { let state: String }
}

struct LightsEntry: TimelineEntry {
    let date: Date
    let state: WidgetState
}

enum WidgetState {
    case loading
    case loaded(response: LightsResponse, failure: String?)
    case error(String)
}

func parseWidgetDate(_ raw: String) -> Date? {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let d = f.date(from: raw) { return d }
    f.formatOptions = [.withInternetDateTime]
    return f.date(from: raw)
}

// Erros do toggle — 503 é MQTT fora do ar, sinalizado à parte.
enum LightsToggleError: Error {
    case invalidURL
    case network
    case mqttDown
    case http(Int)
    case emptyName
    case missingValue
}

// Chama o servidor SEM ir pro app. Identidade via header X-User-Id estático.
// Rota /on|/off (não /toggle): determinística e idempotente — o intent já
// recebe o estado NOVO (value), então expressar o alvo direto evita alternar
// às cegas quando a view do widget está desatualizada.
enum LightsToggleService {
    static func set(name: String, on: Bool) async throws {
        // Guard: nome vazio viraria URL malformada (/api/v1/lights//on) — o bug
        // de agora. Não chama rede com nome vazio.
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            widgetLog.error("toggle: nome da luz vazio, abortando antes da rede")
            throw LightsToggleError.emptyName
        }
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        let verb = on ? "on" : "off"
        let path = "/api/v1/lights/\(encoded)/\(verb)"
        guard let url = URL(string: WidgetConfig.baseUrl + path) else {
            widgetLog.error("toggle: URL inválida \(WidgetConfig.baseUrl)\(path)")
            throw LightsToggleError.invalidURL
        }
        widgetLog.info("toggle: \(verb) <\(name)> -> \(url.absoluteString)")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        // perform() roda no ambiente restrito da extensão com orçamento
        // apertado — mudança rápida de estado, não trabalho pesado de rede.
        // Timeout curto: estourou = falha, volta ao estado anterior.
        request.timeoutInterval = 5
        request.setValue(WidgetConfig.userId, forHTTPHeaderField: "X-User-Id")
        let (_, response): (Data, URLResponse)
        do {
            (_, response) = try await URLSession.shared.data(for: request)
        } catch {
            widgetLog.error("toggle: falha de rede \(url.absoluteString): \(error.localizedDescription)")
            throw LightsToggleError.network
        }
        guard let http = response as? HTTPURLResponse else {
            widgetLog.error("toggle: sem resposta HTTP \(url.absoluteString)")
            throw LightsToggleError.network
        }
        widgetLog.info("toggle: HTTP \(http.statusCode) \(url.absoluteString)")
        guard (200...299).contains(http.statusCode) else {
            if http.statusCode == 503 {
                widgetLog.error("toggle: MQTT fora do ar \(url.absoluteString)")
                throw LightsToggleError.mqttDown
            }
            widgetLog.error("toggle: HTTP \(http.statusCode) \(url.absoluteString)")
            throw LightsToggleError.http(http.statusCode)
        }
    }
}

// ponytail: ponte em memória entre o intent e o provider. Vale quando o
// intent roda no processo da extensão (o caso normal: widget com o app em
// background). Se rodar no processo do app (app em foreground), a mensagem
// não propaga — sobra o snap-back, que ainda é honesto. Upgrade com App
// Group + UserDefaults quando a conta do dev permitir.
final class LightsWidgetError {
    static let shared = LightsWidgetError()
    private init() {}
    var lastFailure: String?
}

// App Intent do toggle interativo — RODA DENTRO da extensão.
// SetValueIntent (não AppIntent): o `Toggle(isOn:intent:)` do SwiftUI exige
// essa conformância — o sistema injeta o estado NOVO em `value` antes de
// chamar perform(). AppIntent puro só funciona com Button(intent:); com o
// Toggle ele vira o ícone de proibido (é o que estava acontecendo).
// Emitimos /on|/off conforme `value` (determinístico), não /toggle.
struct ToggleLightIntent: SetValueIntent {
    static let title: LocalizedStringResource = "Alternar luz"
    static var description = IntentDescription("Liga ou desliga uma luz pelo servidor.")

    @Parameter(title: "Luz") var lightName: String
    @Parameter(title: "Ligada") var value: Bool?

    init() {}
    init(lightName: String) {
        self.lightName = lightName
    }

    func perform() async throws -> some IntentResult {
        // Log cru do que o Toggle injetou — o objetivo da etapa. value pode vir
        // nil (não injetado); loga como chegou, sem fallback.
        widgetLog.info("toggle intent: luz <\(lightName)> value=\(String(describing: value))")
        guard let on = value else {
            widgetLog.error("toggle intent: value não injetado (nil) para <\(lightName)>")
            throw LightsToggleError.missingValue
        }
        do {
            try await LightsToggleService.set(name: lightName, on: on)
        } catch {
            // 503 (MQTT fora do ar) e qualquer erro (inclui timeout): reverte
            // via reload (o GET devolve o estado real, não-mudado → snap-back)
            // e sinaliza a falha na próxima timeline. Rethrow marca a
            // interação como falha no WidgetKit.
            let msg = Self.message(for: error)
            widgetLog.error("toggle intent: falha <\(lightName)> \(msg)")
            LightsWidgetError.shared.lastFailure = msg
            WidgetCenter.shared.reloadTimelines(ofKind: LightWidgetKind)
            throw error
        }
        LightsWidgetError.shared.lastFailure = nil
        WidgetCenter.shared.reloadTimelines(ofKind: LightWidgetKind)
        return .result()
    }

    static func message(for error: Error) -> String {
        if case LightsToggleError.mqttDown = error { return "MQTT fora do ar" }
        if case LightsToggleError.emptyName = error { return "Luz sem nome" }
        if case LightsToggleError.missingValue = error { return "Valor não injetado" }
        return "Falha ao alternar"
    }
}

struct LightsTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> LightsEntry {
        LightsEntry(date: .now, state: .loading)
    }

    // Snapshot para a galeria de widgets: amostra rápida, sem rede.
    func getSnapshot(in context: Context, completion: @escaping (LightsEntry) -> Void) {
        let sample = LightsResponse(
            generatedAt: ISO8601DateFormatter().string(from: .now),
            summary: .init(onCount: 3, total: 8),
            items: [LightItem(name: "Sala", isOn: true)])
        completion(LightsEntry(date: .now, state: .loaded(response: sample, failure: nil)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LightsEntry>) -> Void) {
        let refresh = Date().addingTimeInterval(TimeInterval(WidgetConfig.refreshMinutes * 60))
        fetchLights { response, errorMessage in
            let failure = LightsWidgetError.shared.lastFailure
            LightsWidgetError.shared.lastFailure = nil
            let entry: LightsEntry
            if let response = response {
                entry = LightsEntry(date: .now, state: .loaded(response: response, failure: failure))
            } else {
                entry = LightsEntry(date: .now, state: .error(errorMessage ?? "Erro desconhecido"))
            }
            completion(Timeline(entries: [entry], policy: .after(refresh)))
        }
    }

    private func fetchLights(completion: @escaping (LightsResponse?, String?) -> Void) {
        guard let url = URL(string: WidgetConfig.baseUrl + WidgetConfig.lightsPath) else {
            widgetLog.error("fetch: URL inválida \(WidgetConfig.lightsPath)")
            completion(nil, "URL inválida")
            return
        }
        widgetLog.info("fetch: GET \(url.absoluteString)")
        var request = URLRequest(url: url)
        request.setValue(WidgetConfig.userId, forHTTPHeaderField: "X-User-Id")
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                widgetLog.error("fetch: erro de rede \(url.absoluteString): \(error.localizedDescription)")
                completion(nil, error.localizedDescription)
                return
            }
            guard let http = response as? HTTPURLResponse else {
                widgetLog.error("fetch: sem resposta HTTP \(url.absoluteString)")
                completion(nil, "Sem resposta HTTP")
                return
            }
            widgetLog.info("fetch: HTTP \(http.statusCode) \(url.absoluteString)")
            guard (200...299).contains(http.statusCode) else {
                completion(nil, "HTTP \(http.statusCode)")
                return
            }
            guard let data = data else {
                completion(nil, "Sem corpo na resposta")
                return
            }
            do {
                let decoded = try JSONDecoder().decode(LightsResponse.self, from: data)
                for item in decoded.items {
                    widgetLog.info("fetch: luz <\(item.name)> state=\(item.isOn)")
                }
                completion(decoded, nil)
            } catch {
                widgetLog.error("fetch: falha ao decodificar: \(error.localizedDescription)")
                completion(nil, "Falha ao decodificar: \(error.localizedDescription)")
            }
        }.resume()
    }
}

struct LightsWidgetEntryView: View {
    var entry: LightsEntry

    var body: some View {
        card
            .containerBackground(for: .widget) {
                Color(red: 0.118, green: 0.122, blue: 0.137) // screenBg #1E1F23
            }
    }

    @ViewBuilder
    private var card: some View {
        switch entry.state {
        case .loading:
            VStack(spacing: 8) {
                ProgressView()
                    .tint(Color(red: 0.722, green: 0.878, blue: 0.761)) // accentGreen
                Text("Carregando…")
                    .font(.footnote)
                    .foregroundStyle(.white)
            }
        case .error(let message):
            VStack(alignment: .leading, spacing: 4) {
                Text("Erro")
                    .font(.headline)
                    .foregroundStyle(Color(red: 0.91, green: 0.85, blue: 0.63)) // accentYellow
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(2)
            }
        case .loaded(let response, let failure):
            loadedView(response, failure)
        }
    }

    @ViewBuilder
    private func loadedView(_ response: LightsResponse, _ failure: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Cabeçalho: label + horário (o horário existe porque o dado pode
            // estar velho — recarga de 15 min, orçamento do WidgetKit).
            HStack {
                Text("Luzes")
                    .font(.caption)
                    .foregroundStyle(Color(red: 0.722, green: 0.878, blue: 0.761))
                Spacer()
                timeLabel(asOf: parseWidgetDate(response.generatedAt), raw: response.generatedAt)
            }
            // Toggle interativo da luz principal (a lista inteira não cabe no
            // systemSmall — o systemMedium vem depois com todos os toggles).
            if let light = response.items.first {
                // value é injetado pelo sistema (estado NOVO) — só passamos a
                // luz. SetValueIntent = controle real, não placeholder.
                // NÃO adicionar .toggleStyle(.switch) nem .tint(...) de volta:
                // ambos quebram a RENDERIZAÇÃO do controle no widget (vira o
                // ícone de proibido do WidgetKit — bug já confirmado).
                Toggle(isOn: light.isOn, intent: ToggleLightIntent(lightName: light.name)) {
                    Text(light.name)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
            } else {
                Text("—")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
            }
            // Estado, ou a falha do último toggle (transient, some no próximo
            // reload bem-sucedido).
            if let failure {
                Text(failure)
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .lineLimit(1)
            } else {
                Text("\(response.summary.onCount) de \(response.summary.total) acesas")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func timeLabel(asOf: Date?, raw: String) -> some View {
        if let asOf {
            Text(asOf, style: .time)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.7))
        } else {
            Text(raw)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}

struct LightsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: LightWidgetKind, provider: LightsTimelineProvider()) { entry in
            LightsWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Luzes")
        .description("Qtd de luzes acesas agora.")
        .supportedFamilies([.systemSmall])
    }
}

@main
struct BMOWidgetBundle: WidgetBundle {
    var body: some Widget {
        LightsWidget()
    }
}
