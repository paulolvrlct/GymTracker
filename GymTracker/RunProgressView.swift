import SwiftUI
import SwiftData
import Charts

/// Progression course : courbes d'allure, de distance et de durée par course, avec records.
struct RunProgressSection: View {
    @Query(sort: \RunSession.date) private var runs: [RunSession]
    @State private var metric: Metric = .pace

    enum Metric: String, CaseIterable {
        case pace = "Allure"
        case distance = "Distance"
        case duration = "Durée"
    }

    private var validRuns: [RunSession] {
        runs.filter { $0.distanceMeters > 0 && $0.durationSeconds > 0 }
    }

    /// Une valeur par course, selon la métrique choisie
    private var dataPoints: [(date: Date, value: Double)] {
        validRuns.map { run in
            switch metric {
            case .pace: (run.date, run.averagePaceSecPerKm)
            case .distance: (run.date, run.distanceKm)
            case .duration: (run.date, Double(run.durationSeconds) / 60)
            }
        }
    }

    /// % entre la première et la dernière course (pour l'allure, négatif = plus rapide)
    private var progression: Double? {
        guard dataPoints.count > 1,
              let first = dataPoints.first?.value, first > 0,
              let last = dataPoints.last?.value else { return nil }
        return (last - first) / first * 100
    }

    private var progressionImproved: Bool {
        guard let p = progression else { return false }
        return metric == .pace ? p < 0 : p > 0
    }

    var body: some View {
        if validRuns.isEmpty {
            ContentUnavailableView(
                "Pas encore de course",
                systemImage: "figure.run",
                description: Text("Termine ta première course pour voir tes courbes de progression.")
            )
            .padding(.top, 80)
        } else {
            metricPicker
            chartCard
            statsCard
        }
    }

    // MARK: Sélecteur de métrique

    private var metricPicker: some View {
        Picker("Métrique", selection: $metric) {
            ForEach(Metric.allCases, id: \.self) { Text($0.rawValue) }
        }
        .pickerStyle(.segmented)
    }

    // MARK: Graphique

    private var chartTitle: String {
        switch metric {
        case .pace: "Allure moyenne par course"
        case .distance: "Distance par course"
        case .duration: "Durée par course"
        }
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(chartTitle)
                    .font(.headline)
                Spacer()
                if let progression {
                    Text(String(format: "%+.0f %%", progression))
                        .font(.footnote.weight(.semibold).monospacedDigit())
                        .foregroundStyle(progressionImproved ? .green : .secondary)
                }
            }

            Chart(dataPoints, id: \.date) { point in
                if metric == .distance {
                    BarMark(
                        x: .value("Date", point.date),
                        y: .value("km", point.value)
                    )
                    .foregroundStyle(.green.opacity(0.75))
                    .cornerRadius(4)
                } else {
                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value(metric.rawValue, point.value)
                    )
                    .foregroundStyle(
                        LinearGradient(colors: [.green.opacity(0.3), .green.opacity(0.02)],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("Date", point.date),
                        y: .value(metric.rawValue, point.value)
                    )
                    .foregroundStyle(.green)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Date", point.date),
                        y: .value(metric.rawValue, point.value)
                    )
                    .foregroundStyle(.green)
                    .symbolSize(40)
                }
            }
            .chartYAxis {
                if metric == .pace {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let sec = value.as(Double.self) {
                                Text(PaceFormatter.string(secPerKm: sec)
                                    .replacingOccurrences(of: "/km", with: ""))
                            }
                        }
                    }
                } else {
                    AxisMarks()
                }
            }
            .chartYAxisLabel(metric == .pace ? "min/km" : metric == .distance ? "km" : "min")
            .frame(height: 230)

            if metric == .pace {
                Text("Plus la courbe descend, plus tu cours vite.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }

    // MARK: Records

    private var statsCard: some View {
        HStack(spacing: 12) {
            statTile(title: "Meilleure allure",
                     value: validRuns.map(\.averagePaceSecPerKm).min()
                        .map { PaceFormatter.string(secPerKm: $0).replacingOccurrences(of: "/km", with: "") } ?? "-",
                     icon: "trophy.fill", color: .orange)
            statTile(title: "Plus longue",
                     value: validRuns.map(\.distanceKm).max()
                        .map { String(format: "%.2f km", $0) } ?? "-",
                     icon: "point.topleft.down.to.point.bottomright.curvepath", color: .teal)
            statTile(title: "Total couru",
                     value: String(format: "%.1f km", validRuns.map(\.distanceKm).reduce(0, +)),
                     icon: "sum", color: .green)
        }
    }

    private func statTile(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(color)
            Text(value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
    }
}
