import ActivityKit
import WidgetKit
import SwiftUI

struct RunLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RunActivityAttributes.self) { context in
            // ---- Écran verrouillé ----
            RunLockScreenView(context: context)
                .padding()
                .activityBackgroundTint(Color.black.opacity(0.6))
                .activitySystemActionForegroundColor(.white)

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    metric(value: context.state.distanceKmText, unit: "km", icon: "figure.run")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    metric(value: context.state.paceText, unit: "/km", icon: "speedometer")
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 0) {
                        Text(timerInterval: context.attributes.startedAt...Date.distantFuture,
                             countsDown: false)
                            .font(.title3.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: 64)
                        Text("temps").font(.caption2).foregroundStyle(.white.opacity(0.6))
                    }
                }
            } compactLeading: {
                Image(systemName: "figure.run").foregroundStyle(.green)
            } compactTrailing: {
                Text(context.state.distanceKmText + " km")
                    .monospacedDigit()
                    .foregroundStyle(.white)
            } minimal: {
                Image(systemName: "figure.run").foregroundStyle(.green)
            }
            .keylineTint(.green)
        }
    }

    private func metric(value: String, unit: String, icon: String) -> some View {
        VStack(spacing: 1) {
            Image(systemName: icon).font(.caption2).foregroundStyle(.green)
            Text(value).font(.headline.monospacedDigit()).foregroundStyle(.white)
            Text(unit).font(.caption2).foregroundStyle(.white.opacity(0.6))
        }
    }
}

private struct RunLockScreenView: View {
    let context: ActivityViewContext<RunActivityAttributes>

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Label("Course en cours", systemImage: "figure.run")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
                Spacer()
                Text(timerInterval: context.attributes.startedAt...Date.distantFuture, countsDown: false)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.8))
            }

            HStack(spacing: 0) {
                bigMetric(value: context.state.distanceKmText, unit: "km")
                divider
                bigMetric(value: context.state.paceText, unit: "min/km")
                divider
                bigMetric(value: context.state.durationText, unit: "durée")
            }
        }
    }

    private var divider: some View {
        Rectangle().fill(.white.opacity(0.15)).frame(width: 1, height: 34)
    }

    private func bigMetric(value: String, unit: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title2.monospacedDigit().weight(.bold)).foregroundStyle(.white)
            Text(unit).font(.caption2).foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }
}
