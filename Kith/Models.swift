import Foundation
import SwiftData

// Every property has a default and relationships are optional,
// so these models are ready for iCloud sync later if you turn it on.

@Model
final class Person {
    var id: UUID = UUID()
    var name: String = ""
    var relationship: String = ""
    var phone: String = ""
    var email: String = ""
    var birthdayMonth: Int = 0   // 0 means no birthday saved
    var birthdayDay: Int = 0
    var birthYear: Int = 0       // 0 means year unknown
    var cadenceDays: Int = 30    // how often you want to check in; 0 turns nudges off
    var lastContact: Date?
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \Note.person)
    var notes: [Note]? = []
    @Relationship(deleteRule: .cascade, inverse: \Reminder.person)
    var reminders: [Reminder]? = []
    @Relationship(deleteRule: .cascade, inverse: \KeyDate.person)
    var keyDates: [KeyDate]? = []
    @Relationship(deleteRule: .cascade, inverse: \GiftIdea.person)
    var gifts: [GiftIdea]? = []

    init(name: String) {
        self.name = name
    }
}

@Model
final class Note {
    var id: UUID = UUID()
    var text: String = ""
    var date: Date = Date()
    var pinned: Bool = false
    var isCatchUp: Bool = false
    var person: Person?

    init(text: String, date: Date = .now, isCatchUp: Bool = false) {
        self.text = text
        self.date = date
        self.isCatchUp = isCatchUp
    }
}

@Model
final class Reminder {
    var id: UUID = UUID()
    var text: String = ""
    var due: Date?
    var done: Bool = false
    var doneAt: Date?
    var createdAt: Date = Date()
    var person: Person?

    init(text: String, due: Date?) {
        self.text = text
        self.due = due
    }
}

@Model
final class KeyDate {
    var id: UUID = UUID()
    var label: String = ""
    var date: Date = Date()
    var repeatsYearly: Bool = true
    var person: Person?

    init(label: String, date: Date, repeatsYearly: Bool) {
        self.label = label
        self.date = date
        self.repeatsYearly = repeatsYearly
    }
}

@Model
final class GiftIdea {
    var id: UUID = UUID()
    var text: String = ""
    var given: Bool = false
    var createdAt: Date = Date()
    var person: Person?

    init(text: String) {
        self.text = text
    }
}
