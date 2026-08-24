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
    static let accentBlue = Color(red: 143 / 255, green: 184 / 255, blue: 232 / 255)   // #8FB8E8
    static let taskChip = Color(red: 212 / 255, green: 165 / 255, blue: 116 / 255)     // #D4A574 — espelho de BmoColors.taskChipColor (missões no calendário)
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
    static let calendarPath = "/api/v1/widget/calendar"
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
        // widgetURL como preference do SwiftUI: precisa estar na view raiz do
        // conteúdo do widget — não dentro do switch de entry.state, nem em
        // lightRow, nem depois do containerBackground, senão a preference não
        // chega à raiz e o widget abre o app sem URL.
        card
            .widgetURL(URL(string: "bmo://go/casa"))
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
                // Piso prático: máscara do systemSmall tem raio ~22pt; canto a menos de ~6pt da borda cai fora e é cortado inteiro.
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

// -------------------------------------------------------------------------
// Widget de calendário — systemMedium. Mesma base URL / header / paleta do
// widget de luzes; endpoint /api/v1/widget/calendar.
// -------------------------------------------------------------------------

let CalendarWidgetKind = "CalendarWidget"

// -- Modelos (shape de /api/v1/widget/calendar) --

struct CalendarWidgetResponse: Decodable {
    let kind: String
    let generatedAt: String
    let days: [CalendarDay]

    enum CodingKeys: String, CodingKey {
        case kind
        case generatedAt = "generated_at"
        case days
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kind = (try? c.decode(String.self, forKey: .kind)) ?? ""
        generatedAt = (try? c.decode(String.self, forKey: .generatedAt)) ?? ""
        days = (try? c.decode([CalendarDay].self, forKey: .days)) ?? []
    }

    init(generatedAt: String, days: [CalendarDay]) {
        self.kind = "calendar"
        self.generatedAt = generatedAt
        self.days = days
    }
}

struct CalendarDay: Decodable {
    let date: String
    let isToday: Bool
    let events: [CalendarEvent]
    let eventsOmitted: Int
    let tasks: [CalendarTask]
    let tasksOmitted: Int

    enum CodingKeys: String, CodingKey {
        case date, isToday = "is_today", events, eventsOmitted = "events_omitted",
             tasks, tasksOmitted = "tasks_omitted"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        date = (try? c.decode(String.self, forKey: .date)) ?? ""
        isToday = (try? c.decode(Bool.self, forKey: .isToday)) ?? false
        events = (try? c.decode([CalendarEvent].self, forKey: .events)) ?? []
        eventsOmitted = (try? c.decode(Int.self, forKey: .eventsOmitted)) ?? 0
        tasks = (try? c.decode([CalendarTask].self, forKey: .tasks)) ?? []
        tasksOmitted = (try? c.decode(Int.self, forKey: .tasksOmitted)) ?? 0
    }

    init(date: String, isToday: Bool, events: [CalendarEvent], eventsOmitted: Int,
         tasks: [CalendarTask], tasksOmitted: Int) {
        self.date = date
        self.isToday = isToday
        self.events = events
        self.eventsOmitted = eventsOmitted
        self.tasks = tasks
        self.tasksOmitted = tasksOmitted
    }
}

struct CalendarEvent: Decodable {
    let title: String
    let allDay: Bool
    let startTime: String?
    let endTime: String?
    let kind: String
    let color: String

    enum CodingKeys: String, CodingKey {
        case title, allDay = "all_day", startTime = "start_time", endTime = "end_time",
             kind, color
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        allDay = (try? c.decode(Bool.self, forKey: .allDay)) ?? false
        startTime = (try? c.decodeIfPresent(String.self, forKey: .startTime)) ?? nil
        endTime = (try? c.decodeIfPresent(String.self, forKey: .endTime)) ?? nil
        kind = (try? c.decode(String.self, forKey: .kind)) ?? ""
        color = (try? c.decode(String.self, forKey: .color)) ?? "#8FB8E8"
    }

    init(title: String, allDay: Bool, startTime: String?, endTime: String?, kind: String, color: String) {
        self.title = title
        self.allDay = allDay
        self.startTime = startTime
        self.endTime = endTime
        self.kind = kind
        self.color = color
    }
}

struct CalendarTask: Decodable {
    let title: String
    let dueTime: String?
    let priority: Int
    let isOverdue: Bool

    enum CodingKeys: String, CodingKey {
        case title, dueTime = "due_time", priority, isOverdue = "is_overdue"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        dueTime = (try? c.decodeIfPresent(String.self, forKey: .dueTime)) ?? nil
        priority = (try? c.decode(Int.self, forKey: .priority)) ?? 0
        isOverdue = (try? c.decode(Bool.self, forKey: .isOverdue)) ?? false
    }

    init(title: String, dueTime: String?, priority: Int, isOverdue: Bool) {
        self.title = title
        self.dueTime = dueTime
        self.priority = priority
        self.isOverdue = isOverdue
    }
}

// Célula de conteúdo de um slot. Evento e missão carregam `tomorrow` para o
// esmaecimento 0.45; o rótulo de amanhã é sempre do dia seguinte.
enum CalendarCell {
    case event(CalendarEvent, tomorrow: Bool)
    case task(CalendarTask, tomorrow: Bool)
    case dayLabel

    var tomorrow: Bool {
        switch self {
        case .event(_, let t): return t
        case .task(_, let t): return t
        case .dayLabel: return true
        }
    }

    var itemCount: Int {
        switch self {
        case .dayLabel: return 0
        case .event(_, _), .task(_, _): return 1
        }
    }
}

enum CalendarSlotView {
    case cell(CalendarCell)
    case counter(Int)
    case empty
}

struct CalendarLayout {
    let weekday: String      // "SEGUNDA-FEIRA" — nome do dia por extenso, caixa alta
    let dayNumber: Int
    let slots: [CalendarSlotView]   // sempre 5 (slots 1..5)

    // date chega como "yyyy-MM-dd". Parseia com locale FIXO en_US_POSIX —
    // DateFormatter com locale do aparelho quebra parse de ISO (armadilha
    // clássica). O locale do aparelho entra só na exibição (nome do dia/número).
    static func build(day0: CalendarDay?, day1: CalendarDay?) -> CalendarLayout {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd"

        var weekday = ""
        var dayNumber = 0
        if let day0 = day0, let d = parser.date(from: day0.date) {
            let wf = DateFormatter()
            wf.locale = Locale.current
            wf.dateFormat = "EEEE"
            weekday = wf.string(from: d).uppercased()
            dayNumber = Calendar.current.component(.day, from: d)
        }

        let cap = 5
        // Dentro de cada tipo o servidor já ordena (eventos ordenados, missões
        // ordenadas) — não reordenar no cliente. A única decisão é o intercalar
        // entre os dois tipos: missões primeiro se houver alguma ATRASADA
        // (is_overdue), senão eventos primeiro.
        let todayCells = orderedCells(day: day0, tomorrow: false)
        let tomorrowCells = (day1 != nil && !(day1!.events.isEmpty && day1!.tasks.isEmpty))
            ? [CalendarCell.dayLabel] + orderedCells(day: day1, tomorrow: true)
            : []

        var content: [CalendarCell] = []
        let todayShown = min(todayCells.count, cap)
        content.append(contentsOf: todayCells.prefix(todayShown))
        let remaining = cap - todayShown
        // Regra dura: rótulo de amanhã só se sobrar ao menos UM slot livre
        // depois dele (rótulo sozinho é slot desperdiçado).
        if tomorrowCells.count >= 2 && remaining >= 2 {
            content.append(contentsOf: tomorrowCells.prefix(min(tomorrowCells.count, remaining)))
        }

        let presentItems = (day0?.events.count ?? 0) + (day0?.tasks.count ?? 0)
                        + (day1?.events.count ?? 0) + (day1?.tasks.count ?? 0)
        let omitted = (day0?.eventsOmitted ?? 0) + (day0?.tasksOmitted ?? 0)
                    + (day1?.eventsOmitted ?? 0) + (day1?.tasksOmitted ?? 0)
        let shownItems = content.reduce(0) { $0 + $1.itemCount }
        let wouldOverflow = (presentItems - shownItems) + omitted

        var slots = [CalendarSlotView](repeating: .empty, count: cap)
        if wouldOverflow > 0 {
            var kept = Array(content.prefix(cap - 1))
            // Transborgo: nunca deixar rótulo de amanhã solto na última posição.
            while case .dayLabel? = kept.last { kept.removeLast() }
            let keptItems = kept.reduce(0) { $0 + $1.itemCount }
            for (i, c) in kept.enumerated() { slots[i] = .cell(c) }
            slots[cap - 1] = .counter((presentItems - keptItems) + omitted)
        } else {
            for (i, c) in content.prefix(cap).enumerated() { slots[i] = .cell(c) }
        }

        return CalendarLayout(weekday: weekday, dayNumber: dayNumber, slots: slots)
    }

    static func orderedCells(day: CalendarDay?, tomorrow: Bool) -> [CalendarCell] {
        guard let day else { return [] }
        let events = day.events.map { CalendarCell.event($0, tomorrow: tomorrow) }
        let tasks = day.tasks.map { CalendarCell.task($0, tomorrow: tomorrow) }
        let anyOverdue = day.tasks.contains { $0.isOverdue }
        return anyOverdue ? tasks + events : events + tasks
    }
}

struct CalendarEntry: TimelineEntry {
    let date: Date
    let state: CalendarState
}

enum CalendarState {
    case loading
    case loaded(CalendarWidgetResponse)
    case error(String)
}

struct CalendarTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> CalendarEntry {
        CalendarEntry(date: .now, state: .loading)
    }

    // Snapshot para a galeria: amostra curta, sem rede.
    func getSnapshot(in context: Context, completion: @escaping (CalendarEntry) -> Void) {
        #if DEBUG
        Self._verifyLayout()
        #endif
        completion(CalendarEntry(date: .now, state: .loaded(Self.sample())))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CalendarEntry>) -> Void) {
        fetchCalendar { response, error in
            let entry: CalendarEntry
            if let response = response {
                entry = CalendarEntry(date: .now, state: .loaded(response))
            } else {
                entry = CalendarEntry(date: .now, state: .error(error ?? "Erro desconhecido"))
            }
            // Os rótulos hoje/amanhã mudam de significado à meia-noite: agendar a
            // próxima atualização para o menor valor entre 30min daqui e o
            // primeiro instante após a próxima meia-noite local.
            completion(Timeline(entries: [entry], policy: .after(Self.nextRefreshDate())))
        }
    }

    // Menor entre 30min e a próxima meia-noite local (via calendar, não soma
    // fixa de 86400s — honesto em mudança de horário de verão).
    static func nextRefreshDate() -> Date {
        let now = Date()
        let in30 = now.addingTimeInterval(30 * 60)
        let nextMidnight = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: now))!
        return min(in30, nextMidnight)
    }

    private func fetchCalendar(completion: @escaping (CalendarWidgetResponse?, String?) -> Void) {
        guard let url = URL(string: WidgetConfig.baseUrl + WidgetConfig.calendarPath) else {
            widgetLog.error("calendar fetch: URL inválida \(WidgetConfig.calendarPath)")
            completion(nil, "URL inválida")
            return
        }
        widgetLog.info("calendar fetch: GET \(url.absoluteString)")
        var request = URLRequest(url: url)
        request.setValue(WidgetConfig.userId, forHTTPHeaderField: "X-User-Id")
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                widgetLog.error("calendar fetch: rede \(url.absoluteString): \(error.localizedDescription)")
                completion(nil, error.localizedDescription)
                return
            }
            guard let http = response as? HTTPURLResponse else {
                widgetLog.error("calendar fetch: sem HTTP \(url.absoluteString)")
                completion(nil, "Sem resposta HTTP")
                return
            }
            widgetLog.info("calendar fetch: HTTP \(http.statusCode) \(url.absoluteString)")
            guard (200...299).contains(http.statusCode) else {
                completion(nil, "HTTP \(http.statusCode)")
                return
            }
            guard let data = data else {
                completion(nil, "Sem corpo na resposta")
                return
            }
            do {
                let decoded = try JSONDecoder().decode(CalendarWidgetResponse.self, from: data)
                completion(decoded, nil)
            } catch {
                widgetLog.error("calendar fetch: decode \(error.localizedDescription)")
                completion(nil, "Falha ao decodificar: \(error.localizedDescription)")
            }
        }.resume()
    }

    static func sample() -> CalendarWidgetResponse {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        let now = Date()
        let tomorrowDate = Calendar.current.date(byAdding: .day, value: 1, to: now)!
        let today = CalendarDay(
            date: f.string(from: now), isToday: true,
            events: [
                CalendarEvent(title: "Reunião de planejamento", allDay: false, startTime: "14:00", endTime: "15:30", kind: "meeting", color: "#8FB8E8"),
                CalendarEvent(title: "Evento o dia todo", allDay: true, startTime: nil, endTime: nil, kind: "holiday", color: "#E8D8A0")],
            eventsOmitted: 1,
            tasks: [
                CalendarTask(title: "Enviar relatório", dueTime: "09:00", priority: 1, isOverdue: true),
                CalendarTask(title: "Comprar presente", dueTime: nil, priority: 2, isOverdue: false)],
            tasksOmitted: 0)
        let tomorrow = CalendarDay(
            date: f.string(from: tomorrowDate), isToday: false,
            events: [
                CalendarEvent(title: "Dentista", allDay: false, startTime: "08:00", endTime: "08:30", kind: "appointment", color: "#67E8CD")],
            eventsOmitted: 0,
            tasks: [
                CalendarTask(title: "Pagar conta", dueTime: nil, priority: 3, isOverdue: false)],
            tasksOmitted: 1)
        return CalendarWidgetResponse(generatedAt: ISO8601DateFormatter().string(from: now), days: [today, tomorrow])
    }

    #if DEBUG
    private static func _verifyLayout() {
        let s = sample()
        let l = CalendarLayout.build(day0: s.days.first, day1: s.days.count > 1 ? s.days[1] : nil)
        assert(l.slots.count == 5)
        // Regra dura: rótulo de amanhã nunca é o último slot.
        let lastIsLabel: Bool = {
            if case .cell(.dayLabel) = l.slots.last ?? .empty { return true }
            return false
        }()
        assert(!lastIsLabel)
        // Hoje tem missão atrasada → missões vêm antes de eventos.
        if case .cell(.task(_, _)) = l.slots[0] {} else {
            assertionFailure("com missão atrasada, missões devem vir antes de eventos")
        }
    }
    #endif
}

struct CalendarWidgetEntryView: View {
    var entry: CalendarEntry

    var body: some View {
        // widgetURL na view raiz do conteúdo — se cair depois do
        // containerBackground ou dentro do switch, a preference não chega à
        // raiz e o widget abre o app sem URL.
        card
            .widgetURL(URL(string: "bmo://go/calendario"))
            .containerBackground(for: .widget) {
                BmoPalette.screenBg
            }
    }

    @ViewBuilder
    private var card: some View {
        Group {
            switch entry.state {
            case .loading:
                VStack {
                    Spacer(minLength: 0)
                    ProgressView()
                        .tint(BmoPalette.accentYellow)
                        .frame(maxWidth: .infinity)
                    Spacer(minLength: 0)
                }
            case .error(let message):
                VStack {
                    Spacer(minLength: 0)
                    Text(message)
                        .font(.system(size: 11))
                        .foregroundStyle(BmoPalette.textSecondary)
                        .lineLimit(3)
                    Spacer(minLength: 0)
                }
            case .loaded(let response):
                gridView(response)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .overlay(
            BracketCorners()
                .stroke(BmoPalette.accentBlue, lineWidth: 1.5)
                .padding(14)
        )
    }

    private func gridView(_ response: CalendarWidgetResponse) -> some View {
        let layout = CalendarLayout.build(
            day0: response.days.first,
            day1: response.days.count > 1 ? response.days[1] : nil)
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
            dateBlock(layout)
            ForEach(Array(layout.slots.enumerated()), id: \.offset) { _, slot in
                slotView(slot)
            }
        }
    }

    private func dateBlock(_ layout: CalendarLayout) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(layout.weekday)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(BmoPalette.accentBlue)
                .lineLimit(1)
            Text(String(layout.dayNumber))
                .font(Font.custom("PressStart2P-Regular", size: 30))
                .foregroundStyle(BmoPalette.textPrimary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func slotView(_ slot: CalendarSlotView) -> some View {
        switch slot {
        case .counter(let n):
            Text("mais \(n)")
                .font(.system(size: 10))
                .foregroundStyle(BmoPalette.textMuted)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        case .empty:
            Color.clear
        case .cell(let c):
            cellView(c).opacity(c.tomorrow ? 0.45 : 1)
        }
    }

    @ViewBuilder
    private func cellView(_ c: CalendarCell) -> some View {
        switch c {
        case .event(let e, _):
            eventView(e)
        case .task(let t, _):
            taskView(t)
        case .dayLabel:
            Text(tomorrowWord())
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(BmoPalette.textMuted)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
    }

    private func eventView(_ e: CalendarEvent) -> some View {
        let color = colorFromHex(e.color)
        return HStack(spacing: 6) {
            Rectangle()
                .fill(color)
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 1) {
                Text(e.title)
                    .font(.system(size: 12))
                    .foregroundStyle(BmoPalette.textPrimary)
                    .lineLimit(1)
                if !e.allDay, let interval = timeInterval(e) {
                    Text(interval)
                        .font(.system(size: 11))
                        .foregroundStyle(BmoPalette.textSecondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 5)
        .padding(.trailing, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.14))
    }

    private func taskView(_ t: CalendarTask) -> some View {
        let color = t.isOverdue ? BmoPalette.accentRed : BmoPalette.taskChip
        return HStack(spacing: 5) {
            Circle()
                .stroke(color, lineWidth: 1.5)
                .frame(width: 11, height: 11)
            Text(t.title)
                .font(.system(size: 12))
                .foregroundStyle(BmoPalette.textPrimary)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Capsule().fill(color.opacity(0.14)))
    }

    private func timeInterval(_ e: CalendarEvent) -> String? {
        switch (e.startTime, e.endTime) {
        case (let s?, let e2?): return "\(s)—\(e2)"
        case (let s?, nil): return s
        case (nil, let e2?): return e2
        case (nil, nil): return nil
        }
    }

    private func tomorrowWord() -> String {
        let r = RelativeDateTimeFormatter()
        r.locale = Locale.current
        r.dateTimeStyle = .named   // "amanhã"/"tomorrow"/"demain"
        let todayStart = Calendar.current.startOfDay(for: .now)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: todayStart)!
        return r.localizedString(for: tomorrow, relativeTo: .now).uppercased()
    }

    // #RRGGBB → Color. Fallback accentBlue se cor inválida.
    private func colorFromHex(_ hex: String) -> Color {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt64(s, radix: 16) else { return BmoPalette.accentBlue }
        return Color(red: CGFloat((v >> 16) & 0xFF) / 255,
                     green: CGFloat((v >> 8) & 0xFF) / 255,
                     blue: CGFloat(v & 0xFF) / 255)
    }
}

struct CalendarWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: CalendarWidgetKind, provider: CalendarTimelineProvider()) { entry in
            CalendarWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Calendário")
        .description("Eventos e missões de hoje e amanhã.")
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
    }
}

@main
struct BMOWidgetBundle: WidgetBundle {
    var body: some Widget {
        LightsWidget()
        CalendarWidget()
    }
}
