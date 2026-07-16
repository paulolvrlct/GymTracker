import ActivityKit
import WidgetKit
import SwiftUI

struct RestTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestActivityAttributes.self) { context in
            // ---- Écran verrouillé / bannière ----
            RestLockScreenView(context: context)
                .padding()
                .activityBackgroundTint(Color.black.opacity(0.55))
                .activitySystemActionForegroundColor(.white)

        } dynamicIsland: { context in
            DynamicIsland {
                // ---- Îlot déplié (expanded) ----
                DynamicIslandExpandedRegion(.leading) {
                    Label("Repos", systemImage: "timer")
                        .font(.caption).foregroundStyle(.indigo)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: Date.now...context.state.endDate, countsDown: true)
                        .font(.title2.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 70)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(context.state.exerciseName)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white)
                        ProgressView(timerInterval: Date.now...context.state.endDate,
                                     countsDown: true) { EmptyView() } currentValueLabel: { EmptyView() }
                            .tint(.indigo)
                    }
                }
            } compactLeading: {
                Image(systemName: "timer").foregroundStyle(.indigo)
            } compactTrailing: {
                Text(timerInterval: Date.now...context.state.endDate, countsDown: true)
                    .monospacedDigit()
                    .frame(width: 44)
                    .foregroundStyle(.white)
            } minimal: {
                Image(systemName: "timer").foregroundStyle(.indigo)
            }
            .keylineTint(.indigo)
        }
    }
}

private struct RestLockScreenView: View {
    let context: ActivityViewContext<RestActivityAttributes>

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "timer")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(LinearGradient(colors: [.indigo, .purple],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text("Repos · \(context.attributes.workoutName)")
                    .font(.caption).foregroundStyle(.white.opacity(0.7))
                Text(context.state.exerciseName)
                    .font(.headline).foregroundStyle(.white)
                ProgressView(timerInterval: Date.now...context.state.endDate,
                             countsDown: true) { EmptyView() } currentValueLabel: { EmptyView() }
                    .tint(.indigo)
            }

            Spacer()

            Text(timerInterval: Date.now...context.state.endDate, countsDown: true)
                .font(.title.monospacedDigit().weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 82)
        }
    }
}
