import SwiftUI

struct RootTabView: View {
    @State private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            HomeView()
                .tabItem { Label("Accueil", systemImage: "house.fill") }
                .tag(0)

            TemplatesView()
                .tabItem { Label("Séances", systemImage: "dumbbell.fill") }
                .tag(1)

            RunningView()
                .tabItem { Label("Course", systemImage: "figure.run") }
                .tag(2)

            HistoryView()
                .tabItem { Label("Calendrier", systemImage: "calendar") }
                .tag(3)

            ProgressChartsView()
                .tabItem { Label("Progression", systemImage: "chart.xyaxis.line") }
                .tag(4)
        }
        .tint(.indigo)
        .onAppear {
            NotificationManager.shared.requestAuthorization()
        }
        // Lien profond depuis le widget raccourci (gymtracker://run)
        .onOpenURL { url in
            if url.scheme == "gymtracker", url.host == "run" {
                selection = 2
            }
        }
    }
}

#Preview {
    RootTabView()
        .modelContainer(for: [WorkoutTemplate.self, WorkoutSession.self], inMemory: true)
}
