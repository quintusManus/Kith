import SwiftUI
import SwiftData

struct PeopleListView: View {
    @Environment(\.modelContext) var context
    @Query(sort: \Person.name) var people: [Person]
    @State var search = ""
    @State var showingAdd = false
    @State var pendingDelete: Person?

    init() {}

    private var filtered: [Person] {
        guard !search.isEmpty else { return people }
        return people.filter {
            $0.name.localizedCaseInsensitiveContains(search) ||
            $0.relationship.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filtered) { p in
                    NavigationLink(value: p) { PersonRow(person: p) }
                        .swipeActions {
                            Button(role: .destructive) { pendingDelete = p } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
            .overlay {
                if people.isEmpty {
                    ContentUnavailableView {
                        Label("No one here yet", systemImage: "person.2")
                    } description: {
                        Text("Tap + to add someone you want to keep up with.")
                    }
                } else if filtered.isEmpty {
                    ContentUnavailableView.search(text: search)
                }
            }
            .searchable(text: $search, prompt: "Search people")
            .navigationTitle("People")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingAdd = true } label: { Label("Add person", systemImage: "plus") }
                }
            }
            .navigationDestination(for: Person.self) { PersonDetailView(person: $0) }
            .sheet(isPresented: $showingAdd) { PersonEditView(person: nil) }
            .confirmationDialog(
                "Delete \(pendingDelete?.name ?? "this person")?",
                isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let p = pendingDelete { context.delete(p) }
                    pendingDelete = nil
                }
            } message: {
                Text("Their notes, reminders, and dates will be deleted too.")
            }
        }
    }
}
