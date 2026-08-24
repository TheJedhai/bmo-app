import WidgetKit
import SwiftUI
import AppIntents
import os

// Espelho de lib/core/theme/bmo_theme.dart — mudanças lá precisam ser refletidas
// aqui (mesma paleta, aplicada no widget).
enum BmoPalette {
    static let screenBg = Color(red: 30 / 255, green: 31 / 255, blue: 35 / 255)        // #1E1F23
    static let screenBgElevated = Color(red: 38 / 255, green: 39 / 255, blue: 44 / 255) // #26272C
    static let textPrimary = Color(red: 232 / 255, green: 232 / 255, blue: 232 / 255)  // #E8E8E8
    static let textSecondary = Color(red: 154 / 255, green: 154 / 255, blue: 154 / 255) // #9A9A9A
    static let textMuted = Color(red: 106 / 255, green: 106 / 255, blue: 106 / 255)    // #6A6A6A
    static let accentRed = Color(red: 232 / 255, green: 147 / 255, blue: 138 / 255)    // #E8938A
    static let accentYellow = Color(red: 232 / 255, green: 216 / 255, blue: 160 / 255) // #E8D8A0
}

// Cantos em L — a assinatura visual do DashCard. Quatro cantos, cada perna
// 14 pt, traço 1.5 pt, sem preenchimento (aplicado como stroke em accentRed,
// com inset de 2 pt).
struct BracketCorners: Shape {
    var leg: CGFloat = 14

    func path(in rect: CGRect) -> Path {
        let l = min(leg, min(rect.width, rect.height) / 2)
        var p = Path()
        // topo-esquerda
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + l))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + l, y: rect.minY))
        // topo-direita
        p.move(to: CGPoint(x: rect.maxX - l, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + l))
        // base-direita
        p.move(to: CGPoint(x: rect.maxX, y: rect.maxY - l))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - l, y: rect.maxY))
        // base-esquerda
        p.move(to: CGPoint(x: rect.minX + l, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - l))
        return p
    }
}

// ToggleStyle custom — não usar o .switch do sistema nem .tint: quebram a
// renderização do controle no widget (bug já confirmado).
struct BmoToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            configuration.label
            Spacer(minLength: 0)
            ZStack {
                Capsule()
                    .fill(configuration.isOn ? BmoPalette.accentRed : BmoPalette.screenBgElevated)
                if !configuration.isOn {
                    Capsule().stroke(BmoPalette.textMuted, lineWidth: 1.5)
                }
                Circle()
                    .fill(configuration.isOn ? BmoPalette.screenBg : BmoPalette.textSecondary)
                    .frame(width: 16, height: 16)
                    .offset(x: configuration.isOn ? 9 : -9)
            }
            .frame(width: 40, height: 22)
        }
        .frame(maxWidth: .infinity)
    }
}

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

// Overlay otimista do toggle: o eco do Zigbee2MQTT chega alguns ms depois do
// POST, então o GET que o reloadTimelines dispara pode devolver o estado ainda
// antigo e realimentar o intent do toque seguinte (toque que não muda nada).
// Guardamos o alvo recém-enviado e o aplicamos por cima da resposta enquanto
// ele for recente (<5s). Mesma limitação de processo da ponte acima: vale
// quando intent e provider rodam no processo da extensão. Se rodar no processo
// do app, não propaga — upgrade com App Group + UserDefaults quando der.
final class LightsWidgetOverlay {
    static let shared = LightsWidgetOverlay()
    private init() {}

    struct Target {
        let name: String
        let on: Bool
        let sentAt: Date
    }

    var target: Target?

    // Retorna os items com o alvo aplicado (se ele existir, for recente e casar
    // com algum item). Descarta alvo com mais de 5s. nil = não aplicou.
    func apply(to items: [LightItem]) -> [LightItem]? {
        guard let t = target else { return nil }
        if Date().timeIntervalSince(t.sentAt) >= 5 {
            target = nil
            return nil
        }
        guard let i = items.firstIndex(where: { $0.name == t.name }) else { return nil }
        widgetLog.info("overlay: <\(t.name)> servidor=\(items[i].isOn) overlay=\(t.on)")
        var out = items
        out[i] = LightItem(name: t.name, isOn: t.on)
        return out
    }
}

// App Intent do toggle interativo — RODA DENTRO da extensão.
// SetValueIntent (não AppIntent): o `Toggle(isOn:intent:)` do SwiftUI exige
// essa conformância para a renderização do controle. A conformance é mantida
// também por compatibilidade com um futuro ControlWidgetToggle (Control
// Center) — não porque o sistema injeta `value`. AppIntent puro só funciona
// com Button(intent:); com o Toggle ele vira o ícone de proibido (é o que
// estava acontecendo).
// Emitimos /on|/off conforme `value` (determinístico), não /toggle.
struct ToggleLightIntent: SetValueIntent {
    static let title: LocalizedStringResource = "Alternar luz"
    static var description = IntentDescription("Liga ou desliga uma luz pelo servidor.")

    @Parameter(title: "Luz") var lightName: String
    @Parameter(title: "Ligada", default: false) var value: Bool

    init() {}
    init(lightName: String, on: Bool) {
        self.lightName = lightName
        self.value = on
    }

    func perform() async throws -> some IntentResult {
        // Log cru do alvo. value vem atribuído na construção do intent (pela
        // view), porque widgets de home screen não resolvem parâmetros de app
        // intents — Apple, Adding interactivity to widgets and Live Activities:
        // widgets don't resolve parameters for app intents.
        widgetLog.info("toggle intent: luz <\(lightName)> value=\(value)")
        do {
            try await LightsToggleService.set(name: lightName, on: value)
        } catch {
            // 503 (MQTT fora do ar) e qualquer erro (inclui timeout): reverte
            // via reload (o GET devolve o estado real, não-mudado → snap-back)
            // e sinaliza a falha na próxima timeline. Rethrow marca a
            // interação como falha no WidgetKit. Limpa o overlay: snap-back
            // para o estado real é o comportamento correto quando o comando
            // falhou.
            let msg = Self.message(for: error)
            widgetLog.error("toggle intent: falha <\(lightName)> \(msg)")
            LightsWidgetError.shared.lastFailure = msg
            LightsWidgetOverlay.shared.target = nil
            WidgetCenter.shared.reloadTimelines(ofKind: LightWidgetKind)
            throw error
        }
        LightsWidgetError.shared.lastFailure = nil
        // Grava o alvo otimista e espera o eco do Z2M: o GET do reload logo
        // após o POST tende a devolver o estado antigo (o eco chega depois).
        // Essa pausa resolve a maioria dos casos; o overlay é rede de
        // segurança, não fonte primária.
        LightsWidgetOverlay.shared.target = LightsWidgetOverlay.Target(name: lightName, on: value, sentAt: Date())
        try? await Task.sleep(for: .milliseconds(800))
        WidgetCenter.shared.reloadTimelines(ofKind: LightWidgetKind)
        return .result()
    }

    static func message(for error: Error) -> String {
        if case LightsToggleError.mqttDown = error { return "MQTT fora do ar" }
        if case LightsToggleError.emptyName = error { return "Luz sem nome" }
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
                var r = response
                if let overlaid = LightsWidgetOverlay.shared.apply(to: r.items) {
                    r = LightsResponse(generatedAt: r.generatedAt, summary: r.summary, items: overlaid)
                }
                entry = LightsEntry(date: .now, state: .loaded(response: r, failure: failure))
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
                BmoPalette.screenBg
            }
    }

    @ViewBuilder
    private var card: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Cabeçalho CASA — igual em todos os estados (assinatura do card).
            Text("CASA")
                .font(Font.custom("PressStart2P-Regular", size: 9))
                .foregroundStyle(BmoPalette.accentRed)
            switch entry.state {
            case .loading:
                Spacer(minLength: 0)
                ProgressView()
                    .tint(BmoPalette.accentYellow)
                    .frame(maxWidth: .infinity)
                Spacer(minLength: 0)
            case .error(let message):
                Spacer(minLength: 0)
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(BmoPalette.textSecondary)
                    .lineLimit(3)
                Spacer(minLength: 0)
            case .loaded(let response, let failure):
                countRow(response.summary)
                Spacer(minLength: 0)
                lightRow(response)
                footer(failure, response)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .overlay(
            BracketCorners()
                .stroke(BmoPalette.accentRed, lineWidth: 1.5)
                // Piso prático: a máscara do systemSmall tem raio ~22pt; canto
                // a menos de ~6pt da borda cai fora e é cortado inteiro.
                .padding(14)
        )
    }

    private func countRow(_ summary: LightsResponse.Summary) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "lightbulb")
                .font(.system(size: 13))
                .foregroundStyle(summary.onCount > 0 ? BmoPalette.accentYellow : BmoPalette.accentRed)
            Text(countText(summary))
                .font(.system(size: 12))
                .foregroundStyle(BmoPalette.textSecondary)
                .lineLimit(1)
        }
    }

    private func countText(_ summary: LightsResponse.Summary) -> String {
        "\(summary.onCount) de \(summary.total) " + (summary.total == 1 ? "acesa" : "acesas")
    }

    @ViewBuilder
    private func lightRow(_ response: LightsResponse) -> some View {
        if let light = response.items.first {
            // Widgets NÃO resolvem parâmetros de app intents: o sistema não
            // injeta o estado novo num Toggle de home screen (Apple, Adding
            // interactivity to widgets and Live Activities: widgets don't
            // resolve parameters for app intents). Por isso o alvo (on:) é
            // atribuído na construção, como o exemplo oficial
            // Toggle(isOn:intent:). SetValueIntent = controle real.
            Toggle(isOn: light.isOn, intent: ToggleLightIntent(lightName: light.name, on: !light.isOn)) {
                Text(light.name)
                    .font(.system(size: 13))
                    .foregroundStyle(BmoPalette.textPrimary)
                    .lineLimit(1)
            }
            .toggleStyle(BmoToggleStyle())
        } else {
            Text("—")
                .font(.system(size: 13))
                .foregroundStyle(BmoPalette.textSecondary)
        }
    }

    @ViewBuilder
    private func footer(_ failure: String?, _ response: LightsResponse) -> some View {
        Rectangle()
            .fill(BmoPalette.screenBgElevated)
            .frame(height: 1)
        if let failure {
            Text(failure)
                .font(.system(size: 10))
                .foregroundStyle(BmoPalette.accentYellow)
                .lineLimit(1)
        } else {
            Text(timeText(asOf: parseWidgetDate(response.generatedAt), raw: response.generatedAt))
                .font(.system(size: 10))
                .foregroundStyle(BmoPalette.textMuted)
                .lineLimit(1)
        }
    }

    private func timeText(asOf: Date?, raw: String) -> String {
        guard let asOf else { return raw }
        return asOf.formatted(date: .omitted, time: .shortened)
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
        .contentMarginsDisabled()

    }
}

@main
struct BMOWidgetBundle: WidgetBundle {
    var body: some Widget {
        LightsWidget()
    }
}
