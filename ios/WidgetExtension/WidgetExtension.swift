import WidgetKit
import SwiftUI
import AppIntents

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

    enum CodingKeys: String, CodingKey { case name, state }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
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
}

// Chama o servidor SEM ir pro app. Identidade via header X-User-Id estático.
enum LightsToggleService {
    static func toggle(name: String) async throws {
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        guard let url = URL(string: WidgetConfig.baseUrl + "/api/v1/lights/\(encoded)/toggle") else {
            throw LightsToggleError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(WidgetConfig.userId, forHTTPHeaderField: "X-User-Id")
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw LightsToggleError.network }
        guard (200...299).contains(http.statusCode) else {
            if http.statusCode == 503 { throw LightsToggleError.mqttDown }
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

// App Intent do toggle interativo — RODA DENTRO da extensão. Um `Toggle`
// reflete o estado atual; o tap envia o desejado (inverso do atual). Como a
// rota é /toggle (não idempotente on/off), só chamamos o servidor quando o
// desejado difere do atual — evita toggle duplo por switch desatualizado.
struct ToggleLightIntent: AppIntent {
    static var title: LocalizedStringResource = "Alternar luz"
    static var description = IntentDescription("Alterna uma luz pelo servidor.")

    @Parameter(title: "Luz") var lightName: String
    @Parameter(title: "Estado desejado") var desiredState: Bool
    @Parameter(title: "Estado atual") var currentState: Bool

    init() {}
    init(lightName: String, desiredState: Bool, currentState: Bool) {
        self.lightName = lightName
        self.desiredState = desiredState
        self.currentState = currentState
    }

    func perform() async throws -> some IntentResult {
        if desiredState != currentState {
            do {
                try await LightsToggleService.toggle(name: lightName)
            } catch {
                // 503 (MQTT fora do ar) e qualquer erro: reverte via reload
                // (o GET devolve o estado real, não-mudado → snap-back) e
                // sinaliza a falha na próxima timeline. Rethrow também marca
                // a interação como falha para o WidgetKit.
                LightsWidgetError.shared.lastFailure = Self.message(for: error)
                WidgetCenter.shared.reloadTimelines(ofKind: LightWidgetKind)
                throw error
            }
        }
        LightsWidgetError.shared.lastFailure = nil
        WidgetCenter.shared.reloadTimelines(ofKind: LightWidgetKind)
        return .result()
    }

    static func message(for error: Error) -> String {
        if case LightsToggleError.mqttDown = error { return "MQTT fora do ar" }
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
            completion(nil, "URL inválida")
            return
        }
        var request = URLRequest(url: url)
        request.setValue(WidgetConfig.userId, forHTTPHeaderField: "X-User-Id")
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(nil, error.localizedDescription)
                return
            }
            guard let http = response as? HTTPURLResponse else {
                completion(nil, "Sem resposta HTTP")
                return
            }
            guard (200...299).contains(http.statusCode) else {
                completion(nil, "HTTP \(http.statusCode)")
                return
            }
            guard let data = data else {
                completion(nil, "Sem corpo na resposta")
                return
            }
            do {
                completion(try JSONDecoder().decode(LightsResponse.self, from: data), nil)
            } catch {
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
                Toggle(isOn: light.isOn, intent: ToggleLightIntent(
                    lightName: light.name,
                    desiredState: !light.isOn,
                    currentState: light.isOn)) {
                    Text(light.name)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                .toggleStyle(.switch)
                .tint(Color(red: 0.722, green: 0.878, blue: 0.761))
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
