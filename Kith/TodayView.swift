import SwiftUI
import SwiftData

struct TodayView: View {
    @Query(sort: \Person.name) var people: [Person]
    @State var showingAdd = false

    init() {}

    var body: some View {
        NavigationStack {
            Group {
                if people.isEmpty {
                    ContentUnavailableView {
                        Label("No one here yet", systemImage: "person.crop.circle.badge.plus")
                    } description: {
                        Text("Add someone you want to keep up with. Save their birthday, notes about their life, and reminders to reach out.")
                    } actions: {
                        Button("Add your first person") { showingAdd = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    digestList
                }
            }
            .navigationTitle(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
            .navigationDestination(for: Person.self) { PersonDetailView(person: $0) }
            .sheet(isPresented: $showingAdd) { PersonEditView(person: nil) }
        }
    }

    private var digestList: some View {
        let d = TodayDigest(people: people)
        return List {
            Section {
                Text(d.summary)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))
            }
            if !d.overdue.isEmpty {
                Section("Overdue") { ForEach(d.overdue) { TimelineRow(entry: $0) } }
            }
            if !d.nudges.isEmpty {
                Section("Time to reach out") { ForEach(d.nudges) { NudgeRow(person: $0) } }
            }
            if !d.week.isEmpty {
                Section("Next 7 days") { ForEach(d.week) { TimelineRow(entry: $0) } }
            }
            if !d.later.isEmpty {
                Section("Later this month") { ForEach(d.later) { TimelineRow(entry: $0) } }
            }
            if !d.anytime.isEmpty {
                Section("Anytime") { ForEach(d.anytime) { TimelineRow(entry: $0) } }
            }
        }
    }
}
