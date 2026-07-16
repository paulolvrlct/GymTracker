import SwiftUI

// MARK: - Pluie de confettis (célébration façon Duolingo)

struct ConfettiView: View {
    private struct Particle: Identifiable {
        let id = UUID()
        let x: CGFloat            // position horizontale relative (0...1)
        let delay: Double
        let duration: Double
        let color: Color
        let size: CGFloat
        let spin: Double
    }

    @State private var falling = false

    private let particles: [Particle] = {
        let palette: [Color] = [.indigo, .purple, .green, .orange, .teal, .pink, .yellow]
        return (0..<70).map { _ in
            Particle(
                x: .random(in: 0.02...0.98),
                delay: .random(in: 0...0.7),
                duration: .random(in: 1.8...3.2),
                color: palette.randomElement()!,
                size: .random(in: 7...13),
                spin: .random(in: 360...1080) * (Bool.random() ? 1 : -1)
            )
        }
    }()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { p in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(p.color)
                        .frame(width: p.size, height: p.size * 0.55)
                        .rotationEffect(.degrees(falling ? p.spin : 0))
                        .position(x: p.x * geo.size.width,
                                  y: falling ? geo.size.height + 30 : -30)
                        .animation(.easeIn(duration: p.duration).delay(p.delay), value: falling)
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
        .onAppear { falling = true }
    }
}

// MARK: - Écran de fin de séance

struct WorkoutCelebrationView: View {
    let setCount: Int
    let volume: Double
    let durationSeconds: Int
    var onContinue: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            ConfettiView()

            VStack(spacing: 18) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.yellow)
                    .scaleEffect(appeared ? 1 : 0.2)
                    .rotationEffect(.degrees(appeared ? 0 : -20))

                Text("Séance terminée !")
                    .font(.title.bold())

                Text("Belle séance — continue comme ça 🔥")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    celebrationTile("\(setCount)", "séries")
                    celebrationTile(volume >= 1000 ? String(format: "%.1f t", volume / 1000)
                                                   : "\(Int(volume)) kg", "volume")
                    celebrationTile(PaceFormatter.duration(durationSeconds), "durée")
                }

                Button {
                    onContinue()
                } label: {
                    Text("Continuer")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
            }
            .padding(26)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .padding(.horizontal, 28)
            .scaleEffect(appeared ? 1 : 0.7)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.55).delay(0.05)) {
                appeared = true
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    private func celebrationTile(_ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.headline.monospacedDigit())
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
