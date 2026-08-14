import SwiftUI

// MARK: - Mascotte

/// Petite haltère animée, dessinée **entièrement en SwiftUI**.
///
/// Aucun visuel importé : uniquement des formes vectorielles. Ce choix a des
/// conséquences concrètes — elle s'anime nativement, suit le mode sombre et la
/// couleur d'accent Premium, se décline à n'importe quelle taille, et ajouter
/// une émotion revient à écrire du code plutôt qu'à commander une illustration.
struct MascotView: View {

    enum Mood {
        case idle          // au repos : respiration lente
        case thinking      // penchée, en train de réfléchir
        case happy         // sourire
        case celebrating   // record battu, niveau gagné
    }

    var mood: Mood = .idle
    var size: CGFloat = 52

    @State private var breathing = false
    @State private var blinking = false

    var body: some View {
        ZStack {
            bar
            plate.offset(x: -size * 0.35)
            plate.offset(x:  size * 0.35)
            face
        }
        .frame(width: size, height: size * 0.66)
        .scaleEffect(y: squash, anchor: .bottom)
        .rotationEffect(.degrees(tilt))
        .offset(y: breathing ? -size * 0.035 : size * 0.035)
        .animation(.easeInOut(duration: 1.7).repeatForever(autoreverses: true), value: breathing)
        .animation(.spring(response: 0.35, dampingFraction: 0.55), value: mood)
        .onAppear { breathing = true }
        .task {
            // Clignement irrégulier : un rythme parfaitement régulier donne
            // immédiatement l'impression d'un objet, pas d'un personnage.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Double.random(in: 2.5...5.5)))
                withAnimation(.easeInOut(duration: 0.08)) { blinking = true }
                try? await Task.sleep(for: .milliseconds(110))
                withAnimation(.easeInOut(duration: 0.08)) { blinking = false }
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: Corps

    private var metal: LinearGradient {
        LinearGradient(colors: [Color.brand, .purple],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Barre volontairement courte et épaisse : elle doit porter le visage tout
    /// en laissant les plaques dépasser nettement sur les côtés, sinon la
    /// silhouette se lit comme un simple bloc et non comme une haltère.
    private var bar: some View {
        Capsule().fill(metal)
            .frame(width: size * 0.58, height: size * 0.40)
    }

    private var plate: some View {
        RoundedRectangle(cornerRadius: size * 0.10, style: .continuous)
            .fill(metal)
            .frame(width: size * 0.23, height: size * 0.66)
    }

    // MARK: Visage

    private var face: some View {
        VStack(spacing: size * 0.045) {
            HStack(spacing: size * 0.13) {
                eye
                eye
            }
            if showsMouth { mouth }
        }
        .offset(y: showsMouth ? -size * 0.01 : 0)
    }

    private var eye: some View {
        Capsule().fill(.white)
            .frame(width: size * 0.095, height: size * 0.095 * eyeOpening)
    }

    private var mouth: some View {
        Path { path in
            let w = size * 0.17, h = size * 0.075
            path.move(to: CGPoint(x: 0, y: 0))
            path.addQuadCurve(to: CGPoint(x: w, y: 0),
                              control: CGPoint(x: w / 2, y: h * 1.8))
        }
        .stroke(.white, style: StrokeStyle(lineWidth: size * 0.035, lineCap: .round))
        .frame(width: size * 0.17, height: size * 0.075)
    }

    // MARK: Expressions

    private var showsMouth: Bool { mood == .happy || mood == .celebrating }

    /// 1 = œil grand ouvert, proche de 0 = fermé.
    private var eyeOpening: CGFloat {
        if blinking { return 0.12 }
        switch mood {
        case .happy, .celebrating: return 0.55   // plissé par le sourire
        case .thinking:            return 0.8
        case .idle:                return 1
        }
    }

    /// Écrasement vertical : la base du langage de l'animation cartoon.
    private var squash: CGFloat {
        switch mood {
        case .celebrating: return 1.12
        case .happy:       return 1.05
        default:           return 1
        }
    }

    private var tilt: Double {
        switch mood {
        case .thinking:    return -9
        case .celebrating: return 7
        default:           return 0
        }
    }
}

// MARK: - Bulle de dialogue

/// Bulle affichée sous l'en-tête quand on touche la mascotte.
struct SpeechBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(Color.brand.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(alignment: .topTrailing) {
                // petite pointe orientée vers la mascotte
                MascotBubbleTip()
                    .fill(Color.brand.opacity(0.12))
                    .frame(width: 16, height: 9)
                    .offset(x: -18, y: -8)
            }
    }
}

private struct MascotBubbleTip: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Ce que dit la mascotte

/// Messages **déterministes**, calculés depuis les données réelles.
///
/// Règle de ton, volontairement stricte : on encourage, on ne culpabilise
/// **jamais**. Une séance manquée n'est jamais évoquée, seules les séances
/// faites sont commentées, et rien n'est dit sur l'alimentation ni sur le corps.
/// Duolingo peut se permettre de harceler sur une leçon oubliée ; sur le sport
/// et la nourriture, les enjeux ne sont pas les mêmes.
///
/// C'est aussi la couche de repli du futur coach embarqué : sur un appareil sans
/// Apple Intelligence, l'utilisateur lira ces phrases-ci plutôt que rien.
enum MascotCoach {

    static func message(totalSessions: Int,
                        streak: Int,
                        sessionsThisWeek: Int,
                        kmThisMonth: Double) -> String {
        if totalSessions == 0 {
            return String(localized: "Prêt quand tu veux. Une première séance, et on commence à mesurer.")
        }
        if streak >= 3 {
            return String(localized: "\(streak) jours d'affilée. C'est exactement comme ça que ça marche.")
        }
        if sessionsThisWeek >= 2 {
            return String(localized: "\(sessionsThisWeek) séances cette semaine. Du solide.")
        }
        if sessionsThisWeek == 1 {
            return String(localized: "Une séance cette semaine, c'est déjà du concret.")
        }
        if kmThisMonth >= 10 {
            return String(localized: "Tes jambes travaillent : ça fait des kilomètres, ce mois-ci.")
        }
        return String(localized: "Content de te voir. Quand tu veux, on s'y met.")
    }
}

// MARK: - Lecture du bilan

extension MascotCoach {

    /// Phrase tirée du bilan croisé, ou nil s'il n'y a rien de notable à dire.
    ///
    /// Deux règles de rédaction :
    ///
    /// - **Aucune causalité inventée.** « Ton développé stagne *parce que* tu
    ///   cours » n'est pas établi. On écrit « sur la même période » : le
    ///   rapprochement est fourni, l'interprétation reste à l'utilisateur.
    /// - **Rien sur l'alimentation.** Le bilan calcule l'apport calorique, mais
    ///   la mascotte n'en parle jamais spontanément. Un chiffre non demandé, sur
    ///   ce sujet-là, se reçoit mal.
    static func insight(_ briefing: CoachBriefing) -> String? {
        if let exercise = briefing.stalledExercise, briefing.stalledWeeks >= 3 {
            let weeks = briefing.stalledWeeks

            if briefing.volumeTonnes.isNotable,
               let change = briefing.volumeTonnes.changePercent, change < 0 {
                let drop = Int(abs(change))
                return String(localized: "\(exercise) plafonne depuis \(weeks) semaines. Sur la même période, ton volume a baissé de \(drop) %.")
            }
            if briefing.kilometres.isNotable,
               let change = briefing.kilometres.changePercent, change > 0 {
                let rise = Int(change)
                return String(localized: "\(exercise) plafonne depuis \(weeks) semaines, pendant que ta course augmentait de \(rise) %.")
            }
            return String(localized: "\(exercise) plafonne depuis \(weeks) semaines.")
        }

        if briefing.volumeTonnes.isNotable,
           let change = briefing.volumeTonnes.changePercent, change > 0 {
            let rise = Int(change)
            return String(localized: "Ton volume a augmenté de \(rise) % sur deux semaines.")
        }
        if briefing.kilometres.isNotable,
           let change = briefing.kilometres.changePercent, change > 0 {
            let rise = Int(change)
            return String(localized: "Tu as couru \(rise) % de plus que les deux semaines précédentes.")
        }
        return nil
    }
}
