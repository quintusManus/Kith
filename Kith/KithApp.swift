import SwiftUI
import SwiftData

@main
struct KithApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Person.self, Note.self, Reminder.self, KeyDate.self, GiftIdea.self])
    }
}

struct ContentView: View {
    @Environment(\.modelContext) var context
    @Environment(\.scenePhase) var scenePhase

    init() {}

    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "sun.max") }
            PeopleListView()
                .tabItem { Label("People", systemImage: "person.2") }
        }
        .tint(Theme.accent)
        .task {
            await NotificationManager.shared.requestAuthorization()
            NotificationManager.shared.reschedule(context: context)
        }
        .onChange(of: scenePhase) { _, phase in
            // Refresh scheduled notifications whenever you leave the app.
            if phase == .background || phase == .inactive {
                NotificationManager.shared.reschedule(context: context)
            }
        }
    }
}
