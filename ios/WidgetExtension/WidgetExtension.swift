import WidgetKit
import SwiftUI

// Configuração estática de identidade — mesmo padrão dos headers por agente
// do MCP: identidade por configuração, o cliente não escolhe.
enum WidgetConfig {
    static let baseUrl = "https://jedhais-mac-mini.taild5baed.ts.net"
    static let userId = "1" // Jedhai
    static let lightsPath = "/api/v1/widget/lights"
    static let refreshMinutes = 15
}

// Envelope: { kind, generated_at, total_count, summary: { on_count, total }, items: [...] }
// Déclara só o que usamos; chaves extras no JSON são ignoradas pelo Decodable.
struct LightsResponse: Decodable {
    let generatedAt: String
    let summary: Summary

    enum CodingKeys: String, CodingKey {
        case generatedAt = "generated_at"
        case summary
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

struct LightsEntry: TimelineEntry {
    let date: Date
    let state: WidgetState
}

enum WidgetState {
    case loading
    case loaded(on: Int, total: Int, asOf: Date?, asOfRaw: String)
    case error(String)
}

struct LightsTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> LightsEntry {
        LightsEntry(date: .now, state: .loading)
    }

    // Snapshot para o repositório de widgets (galeria): amostra rápida, sem
    // rede, para não segurar a preview.
    func getSnapshot(in context: Context, completion: @escaping (LightsEntry) -> Void) {
        completion(LightsEntry(date: .now, state: .loaded(on: 3, total: 8, asOf: .now, asOfRaw: "")))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LightsEntry>) -> Void) {
        let refresh = Date().addingTimeInterval(TimeInterval(WidgetConfig.refreshMinutes * 60))
        fetchLights { response, errorMessage in
            let entry: LightsEntry
            if let response = response {
                entry = LightsEntry(date: .now, state: .loaded(
                    on: response.summary.onCount,
                    total: response.summary.total,
                    asOf: Self.parse(response.generatedAt),
                    asOfRaw: response.generatedAt))
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

    private static func parse(_ raw: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: raw) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: raw)
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
        case .loaded(let on, let total, let asOf, let asOfRaw):
            VStack(alignment: .leading, spacing: 6) {
                Text("Luzes")
                    .font(.caption)
                    .foregroundStyle(Color(red: 0.722, green: 0.878, blue: 0.761))
                Text("\(on) de \(total)\nacesas")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                timeLabel(asOf: asOf, raw: asOfRaw)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
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
    let kind: String = "LightsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LightsTimelineProvider()) { entry in
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
