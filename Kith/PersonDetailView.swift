import SwiftUI
import SwiftData

struct PersonDetailView: View {
    @Environment(\.modelContext) var context
    @Environment(\.dismiss) var dismiss
    @Bindable var person: Person
    @State var sheet: DetailSheet?
    @State var newGift = ""
    @State var showDone = false

    init(person: Person) {
        self.person = person
    }

    enum DetailSheet: Identifiable {
        case edit, catchUp, reminder, keyDate
        case note(Note?)

        var id: String {
            switch self {
            case .edit: return "edit"
            case .catchUp: return "catchUp"
            case .reminder: return "reminder"
            case .keyDate: return "keyDate"
            case .note(let n): return "note-\(n?.id.uuidString ?? "new")"
            }
        }
    }

    var body: some View {
        List {
            Section { header }
                .listRowBackground(Color.clear)

            Section("Reminders") {
                ForEach(person.openReminders) { r in
                    ReminderRow(reminder: r)
                        .swipeActions {
                            Button(role: .destructive) { remove(r) } label: { Label("Delete", systemImage: "trash") }
                        }
                }
                Button { sheet = .reminder } label: { Label("Add reminder", systemImage: "plus") }
                if !person.doneReminders.isEmpty {
                    DisclosureGroup("\(plural(person.doneReminders.count, "completed reminder"))", isExpanded: $showDone) {
                        ForEach(person.doneReminders) { r in
                            ReminderRow(reminder: r)
                                .swipeActions {
                                    Button(role: .destructive) { remove(r) } label: { Label("Delete", systemImage: "trash") }
                                }
                        }
                    }
                }
            }

            Section("Notes") {
                Button { sheet = .note(nil) } label: { Label("Add note", systemImage: "square.and.pencil") }
                ForEach(person.sortedNotes) { note in
                    Button { sheet = .note(note) } label: { NoteRow(note: note) }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .leading) {
                            Button { withAnimation { note.pinned.toggle() } } label: {
                                Label(note.pinned ? "Unpin" : "Pin", systemImage: note.pinned ? "pin.slash" : "pin")
                            }
                            .tint(Theme.accent)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) { remove(note) } label: { Label("Delete", systemImage: "trash") }
                        }
                }
            }

            Section("Important dates") {
                ForEach(person.sortedDates) { k in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(k.label)
                            if let nd = k.nextOccurrence {
                                Text(nd.formatted(.dateTime.month(.wide).day().year()) + (k.repeatsYearly ? ", every year" : ""))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer(minLength: 8)
                        if let nd = k.nextOccurrence {
                            let diff = Day.between(.now, nd)
                            Text(diff < 0 ? "Passed" : diff == 0 ? "Today" : "in \(plural(diff, "day"))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions {
                        Button(role: .destructive) { remove(k) } label: { Label("Delete", systemImage: "trash") }
                    }
                }
                Button { sheet = .keyDate } label: { Label("Add date", systemImage: "calendar.badge.plus") }
            }

            Section("Gift ideas") {
                ForEach(person.sortedGifts) { g in
                    HStack(spacing: 12) {
                        Button { withAnimation { g.given.toggle() } } label: {
                            Image(systemName: g.given ? "checkmark.circle.fill" : "gift")
                                .font(.title3)
                                .foregroundStyle(g.given ? Theme.accent : Color.secondary)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(g.given ? "Mark as not given" : "Mark as given")
                        Text(g.text)
                            .strikethrough(g.given)
                            .foregroundStyle(g.given ? Color.secondary : Color.primary)
                    }
                    .swipeActions {
                        Button(role: .destructive) { remove(g) } label: { Label("Delete", systemImage: "trash") }
                    }
                }
                TextField("Add a gift idea", text: $newGift)
                    .submitLabel(.done)
                    .onSubmit(addGift)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) { Button("Edit") { sheet = .edit } }
        }
        .sheet(item: $sheet) { s in
            switch s {
            case .edit: PersonEditView(person: person, onDelete: deletePerson)
            case .catchUp: CatchUpSheet(person: person)
            case .reminder: ReminderSheet(person: person)
            case .keyDate: KeyDateSheet(person: person)
            case .note(let n): NoteSheet(person: person, note: n)
            }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 16) {
                WarmthAvatar(person: person, size: 76)
                VStack(alignment: .leading, spacing: 2) {
                    Text(person.name).font(.system(.title, design: .serif))
                    if !person.relationship.isEmpty {
                        Text(person.relationship).foregroundStyle(.secondary)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                if let nb = person.nextBirthday {
                    let diff = Day.between(.now, nb)
                    let turns = person.turningAge.map { ", turns \($0)" } ?? ""
                    Label("\(nb.formatted(.dateTime.month(.wide).day())) (\(diff == 0 ? "today" : "in \(plural(diff, "day"))")\(turns))",
                          systemImage: "gift")
                }
                if !person.phone.isEmpty,
                   let url = URL(string: "tel:\(person.phone.filter { $0.isNumber || $0 == "+" })") {
                    Link(destination: url) { Label(person.phone, systemImage: "phone") }
                }
                if !person.email.isEmpty, let url = URL(string: "mailto:\(person.email)") {
                    Link(destination: url) { Label(person.email, systemImage: "envelope") }
                }
            }
            .font(.subheadline)

            Text(statusLine)
                .font(.subheadline)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background((person.nudgeDue ? Theme.due : Theme.accent).opacity(0.13),
                            in: RoundedRectangle(cornerRadius: 12))

            Button { sheet = .catchUp } label: {
                Label("Log a catch-up", systemImage: "checkmark.bubble").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .buttonStyle(.borderless)
        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
    }

    private var statusLine: String {
        var s = person.lastContact == nil
            ? "No catch-ups logged yet."
            : "Last caught up \(Day.ago(person.daysSinceContact))."
        if person.cadenceDays > 0 {
            s += " You want to check in \(Cadence.label(for: person.cadenceDays).lowercased())."
            if person.nudgeDue { s += " It's time to reach out." }
        }
        return s
    }

    // MARK: Actions

    private func addGift() {
        let t = newGift.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        let g = GiftIdea(text: t)
        context.insert(g)
        g.person = person
        newGift = ""
    }

    private func remove(_ r: Reminder) { person.reminders?.removeAll { $0 === r }; context.delete(r) }
    private func remove(_ n: Note) { person.notes?.removeAll { $0 === n }; context.delete(n) }
    private func remove(_ k: KeyDate) { person.keyDates?.removeAll { $0 === k }; context.delete(k) }
    private func remove(_ g: GiftIdea) { person.gifts?.removeAll { $0 === g }; context.delete(g) }

    private func deletePerson() {
        sheet = nil
        dismiss()
        let p = person
        let ctx = context
        // Wait for the screen to close before deleting, so nothing reads the deleted record.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { ctx.delete(p) }
    }
}
