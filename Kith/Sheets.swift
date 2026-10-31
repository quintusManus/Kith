import SwiftUI
import SwiftData

// MARK: - Add / edit person

struct PersonEditView: View {
    @Environment(\.modelContext) var context
    @Environment(\.dismiss) var dismiss
    let person: Person?
    var onDelete: (() -> Void)?

    @State var name = ""
    @State var relationship = ""
    @State var phone = ""
    @State var email = ""
    @State var hasBirthday = false
    @State var month = 1
    @State var day = 1
    @State var year = ""
    @State var cadence = 30
    @State var hasLastContact = false
    @State var lastContact = Date.now
    @State var confirmDelete = false
    @State var loaded = false

    init(person: Person?, onDelete: (() -> Void)? = nil) {
        self.person = person
        self.onDelete = onDelete
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name).textContentType(.name)
                    TextField("Relationship (family, college friend…)", text: $relationship)
                }
                Section("Birthday") {
                    Toggle("Add birthday", isOn: $hasBirthday.animation())
                    if hasBirthday {
                        Picker("Month", selection: $month) {
                            ForEach(1...12, id: \.self) { m in
                                Text(Calendar.current.monthSymbols[m - 1]).tag(m)
                            }
                        }
                        Picker("Day", selection: $day) {
                            ForEach(1...31, id: \.self) { Text("\($0)").tag($0) }
                        }
                        TextField("Birth year (optional)", text: $year).keyboardType(.numberPad)
                    }
                }
                Section("Contact") {
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Section {
                    Picker("Check in", selection: $cadence) {
                        ForEach(Cadence.options, id: \.days) { Text($0.label).tag($0.days) }
                    }
                    Toggle("I know when we last caught up", isOn: $hasLastContact.animation())
                    if hasLastContact {
                        DatePicker("Last caught up", selection: $lastContact, in: ...Date.now, displayedComponents: .date)
                    }
                } footer: {
                    Text("Kith nudges you when it's been this long since your last catch-up.")
                }
                if person != nil {
                    Section {
                        Button("Delete person", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .navigationTitle(person.map { "Edit \($0.firstName)" } ?? "Add person")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(person == nil ? "Add" : "Save") { save() }.disabled(trimmedName.isEmpty)
                }
            }
            .confirmationDialog("Delete \(person?.name ?? "")?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { onDelete?() }
            } message: {
                Text("Their notes, reminders, and dates will be deleted too.")
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        guard let p = person else { return }
        name = p.name
        relationship = p.relationship
        phone = p.phone
        email = p.email
        hasBirthday = p.hasBirthday
        if p.hasBirthday { month = p.birthdayMonth; day = p.birthdayDay }
        year = p.birthYear > 0 ? String(p.birthYear) : ""
        cadence = p.cadenceDays
        if let lc = p.lastContact { hasLastContact = true; lastContact = lc }
    }

    private func save() {
        let p: Person
        if let person {
            p = person
        } else {
            p = Person(name: trimmedName)
            context.insert(p)
        }
        let maxDays = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
        p.name = trimmedName
        p.relationship = relationship.trimmingCharacters(in: .whitespacesAndNewlines)
        p.phone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        p.email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        p.birthdayMonth = hasBirthday ? month : 0
        p.birthdayDay = hasBirthday ? min(day, maxDays[month - 1]) : 0
        p.birthYear = hasBirthday ? (Int(year) ?? 0) : 0
        p.cadenceDays = cadence
        p.lastContact = hasLastContact ? lastContact : nil
        dismiss()
    }
}

// MARK: - Log a catch-up

struct CatchUpSheet: View {
    @Environment(\.modelContext) var context
    @Environment(\.dismiss) var dismiss
    let person: Person
    @State var date = Date.now
    @State var text = ""

    init(person: Person) { self.person = person }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("When", selection: $date, in: ...Date.now, displayedComponents: .date)
                Section("What did you talk about? (optional)") {
                    TextEditor(text: $text).frame(minHeight: 140)
                }
            }
            .navigationTitle("Catch-up with \(person.firstName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        if person.lastContact.map({ date > $0 }) ?? true {
            person.lastContact = date
        }
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty {
            let n = Note(text: t, date: date, isCatchUp: true)
            context.insert(n)
            n.person = person
        }
        dismiss()
    }
}

// MARK: - New reminder

struct ReminderSheet: View {
    @Environment(\.modelContext) var context
    @Environment(\.dismiss) var dismiss
    let person: Person
    @State var text = ""
    @State var hasDue = true
    @State var due = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
    @FocusState var focused: Bool

    init(person: Person) { self.person = person }

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Reach out about the graduation", text: $text, axis: .vertical)
                        .focused($focused)
                    Toggle("Due date", isOn: $hasDue.animation())
                    if hasDue {
                        DatePicker("Date", selection: $due, displayedComponents: .date)
                    }
                } footer: {
                    if hasDue { Text("You'll get a notification at 9 AM that day.") }
                }
            }
            .navigationTitle("Reminder for \(person.firstName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Add") { save() }.disabled(trimmed.isEmpty) }
            }
            .onAppear { focused = true }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        let r = Reminder(text: trimmed, due: hasDue ? due : nil)
        context.insert(r)
        r.person = person
        dismiss()
    }
}

// MARK: - New / edit note

struct NoteSheet: View {
    @Environment(\.modelContext) var context
    @Environment(\.dismiss) var dismiss
    let person: Person
    let note: Note?
    @State var text = ""
    @State var pinned = false
    @State var loaded = false
    @FocusState var focused: Bool

    init(person: Person, note: Note?) {
        self.person = person
        self.note = note
    }

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $text)
                        .frame(minHeight: 180)
                        .focused($focused)
                } footer: {
                    Text("Something to remember about \(person.firstName).")
                }
                Toggle("Pin to top", isOn: $pinned)
            }
            .navigationTitle(note == nil ? "New note" : "Edit note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.disabled(trimmed.isEmpty) }
            }
            .onAppear {
                guard !loaded else { return }
                loaded = true
                text = note?.text ?? ""
                pinned = note?.pinned ?? false
                focused = true
            }
        }
    }

    private func save() {
        if let note {
            note.text = trimmed
            note.pinned = pinned
        } else {
            let n = Note(text: trimmed)
            n.pinned = pinned
            context.insert(n)
            n.person = person
        }
        dismiss()
    }
}

// MARK: - New important date

struct KeyDateSheet: View {
    @Environment(\.modelContext) var context
    @Environment(\.dismiss) var dismiss
    let person: Person
    @State var label = ""
    @State var date = Date.now
    @State var repeats = true
    @FocusState var focused: Bool

    init(person: Person) { self.person = person }

    private var trimmed: String { label.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Graduation, anniversary…", text: $label).focused($focused)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    Toggle("Repeats every year", isOn: $repeats)
                } footer: {
                    Text("You'll get a notification at 9 AM on the day.")
                }
            }
            .navigationTitle("Date for \(person.firstName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Add") { save() }.disabled(trimmed.isEmpty) }
            }
            .onAppear { focused = true }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        let k = KeyDate(label: trimmed, date: date, repeatsYearly: repeats)
        context.insert(k)
        k.person = person
        dismiss()
    }
}
