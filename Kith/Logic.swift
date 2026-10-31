import Foundation

func plural(_ n: Int, _ word: String) -> String {
    "\(n) \(word)\(n == 1 ? "" : "s")"
}

struct Cadence {
    let days: Int
    let label: String

    static let options: [Cadence] = [
        Cadence(days: 0, label: "Don't nudge me"),
        Cadence(days: 7, label: "Every week"),
        Cadence(days: 14, label: "Every two weeks"),
        Cadence(days: 30, label: "Every month"),
        Cadence(days: 60, label: "Every two months"),
        Cadence(days: 90, label: "Every three months"),
        Cadence(days: 182, label: "Every six months"),
        Cadence(days: 365, label: "Every year"),
    ]

    static func label(for days: Int) -> String {
        options.first { $0.days == days }?.label ?? "Every \(plural(days, "day"))"
    }
}

enum Day {
    static var cal: Calendar { Calendar.current }

    static func start(_ d: Date) -> Date { cal.startOfDay(for: d) }

    /// Whole days from a to b (positive when b is later).
    static func between(_ a: Date, _ b: Date) -> Int {
        cal.dateComponents([.day], from: start(a), to: start(b)).day ?? 0
    }

    static func isLeap(_ y: Int) -> Bool { (y % 4 == 0 && y % 100 != 0) || y % 400 == 0 }

    /// The next time this month/day comes around, counting today.
    static func nextAnnual(month: Int, day: Int, from ref: Date = .now) -> Date? {
        let today = start(ref)
        let year = cal.component(.year, from: today)
        func make(_ y: Int) -> Date? {
            let d = (month == 2 && day == 29 && !isLeap(y)) ? 28 : day
            return cal.date(from: DateComponents(year: y, month: month, day: d))
        }
        guard let thisYear = make(year) else { return nil }
        return thisYear < today ? make(year + 1) : thisYear
    }

    static func relative(_ diff: Int, date: Date) -> String {
        switch diff {
        case ..<0: return "\(plural(-diff, "day")) late"
        case 0: return "Today"
        case 1: return "Tomorrow"
        case 2..<7: return date.formatted(.dateTime.weekday(.wide))
        default: return date.formatted(.dateTime.month(.abbreviated).day())
        }
    }

    static func span(_ days: Int) -> String {
        switch days {
        case ..<14: return plural(max(days, 1), "day")
        case 14..<60: return plural(Int((Double(days) / 7).rounded()), "week")
        case 60..<730: return plural(Int((Double(days) / 30.4).rounded()), "month")
        default: return plural(Int((Double(days) / 365).rounded()), "year")
        }
    }

    static func ago(_ days: Int) -> String {
        switch days {
        case ..<1: return "today"
        case 1: return "yesterday"
        default: return "\(span(days)) ago"
        }
    }
}

struct UpcomingEvent: Identifiable {
    let id: String
    let title: String
    let date: Date
    let diff: Int
    let isBirthday: Bool
    let person: Person
}

extension KeyDate {
    var nextOccurrence: Date? {
        if repeatsYearly {
            let c = Calendar.current.dateComponents([.month, .day], from: date)
            return Day.nextAnnual(month: c.month ?? 1, day: c.day ?? 1)
        }
        return Day.start(date)
    }
}

extension Person {
    var firstName: String {
        name.split(separator: " ").first.map(String.init) ?? name
    }

    var initials: String {
        let letters = name.split(separator: " ").prefix(2).compactMap { $0.first }
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }

    /// A stable color per person, from 0 to 1.
    var hue: Double {
        var h: UInt32 = 0
        for u in name.unicodeScalars { h = h &* 31 &+ u.value }
        let hues: [Double] = [12, 36, 88, 150, 178, 205, 232, 265, 300, 340]
        return hues[Int(h % UInt32(hues.count))] / 360
    }

    var hasBirthday: Bool { birthdayMonth > 0 && birthdayDay > 0 }

    var nextBirthday: Date? {
        hasBirthday ? Day.nextAnnual(month: birthdayMonth, day: birthdayDay) : nil
    }

    var turningAge: Int? {
        guard birthYear > 0, let nb = nextBirthday else { return nil }
        return Calendar.current.component(.year, from: nb) - birthYear
    }

    var contactBase: Date { lastContact ?? createdAt }
    var daysSinceContact: Int { max(0, Day.between(contactBase, .now)) }
    var nudgeDue: Bool { cadenceDays > 0 && daysSinceContact >= cadenceDays }

    /// 1 right after a catch-up, draining to 0 when it's time to reach out.
    var warmth: Double {
        cadenceDays > 0 ? max(0, 1 - Double(daysSinceContact) / Double(cadenceDays)) : 0
    }

    var nextCheckIn: Date? {
        cadenceDays > 0 ? Calendar.current.date(byAdding: .day, value: cadenceDays, to: Day.start(contactBase)) : nil
    }

    var openReminders: [Reminder] {
        (reminders ?? []).filter { !$0.done }
            .sorted { ($0.due ?? .distantFuture, $0.createdAt) < ($1.due ?? .distantFuture, $1.createdAt) }
    }

    var doneReminders: [Reminder] {
        (reminders ?? []).filter { $0.done }
            .sorted { ($0.doneAt ?? .distantPast) > ($1.doneAt ?? .distantPast) }
    }

    var sortedNotes: [Note] {
        (notes ?? []).sorted {
            if $0.pinned != $1.pinned { return $0.pinned }
            return $0.date > $1.date
        }
    }

    var sortedDates: [KeyDate] {
        (keyDates ?? []).sorted { ($0.nextOccurrence ?? .distantFuture) < ($1.nextOccurrence ?? .distantFuture) }
    }

    var sortedGifts: [GiftIdea] {
        (gifts ?? []).sorted {
            if $0.given != $1.given { return !$0.given }
            return $0.createdAt < $1.createdAt
        }
    }

    func events(within horizon: Int) -> [UpcomingEvent] {
        var out: [UpcomingEvent] = []
        if let nb = nextBirthday {
            let diff = Day.between(.now, nb)
            if diff <= horizon {
                let title = turningAge.map { "Birthday, turning \($0)" } ?? "Birthday"
                out.append(UpcomingEvent(id: "b-\(id)", title: title, date: nb, diff: diff, isBirthday: true, person: self))
            }
        }
        for k in keyDates ?? [] {
            guard let nd = k.nextOccurrence else { continue }
            let diff = Day.between(.now, nd)
            if diff >= 0 && diff <= horizon {
                out.append(UpcomingEvent(id: "k-\(k.id)", title: k.label, date: nd, diff: diff, isBirthday: false, person: self))
            }
        }
        return out.sorted { $0.diff < $1.diff }
    }

    var subtitle: String {
        if nudgeDue { return "Time to reach out" }
        if let e = events(within: 30).first {
            let when = e.diff == 0 ? "today" : e.diff == 1 ? "tomorrow" : "in \(plural(e.diff, "day"))"
            return "\(e.isBirthday ? "Birthday" : e.title) \(when)"
        }
        let n = openReminders.count
        if n > 0 { return plural(n, "open reminder") }
        return relationship.isEmpty ? "No reminders" : relationship
    }
}

// MARK: - Today page grouping

struct TimelineEntry: Identifiable {
    enum Kind {
        case reminder(Reminder)
        case event(UpcomingEvent)
    }
    let kind: Kind
    let person: Person
    let diff: Int

    var id: String {
        switch kind {
        case .reminder(let r): return "r-\(r.id)"
        case .event(let e): return e.id
        }
    }
}

struct TodayDigest {
    var overdue: [TimelineEntry] = []
    var week: [TimelineEntry] = []
    var later: [TimelineEntry] = []
    var anytime: [TimelineEntry] = []
    var nudges: [Person] = []

    init(people: [Person]) {
        for p in people {
            for r in p.openReminders {
                guard let due = r.due else {
                    anytime.append(TimelineEntry(kind: .reminder(r), person: p, diff: .max))
                    continue
                }
                let diff = Day.between(.now, due)
                let e = TimelineEntry(kind: .reminder(r), person: p, diff: diff)
                if diff < 0 { overdue.append(e) }
                else if diff <= 7 { week.append(e) }
                else if diff <= 30 { later.append(e) }
            }
            for ev in p.events(within: 30) {
                let e = TimelineEntry(kind: .event(ev), person: p, diff: ev.diff)
                if ev.diff <= 7 { week.append(e) } else { later.append(e) }
            }
            if p.nudgeDue { nudges.append(p) }
        }
        overdue.sort { $0.diff < $1.diff }
        week.sort { $0.diff < $1.diff }
        later.sort { $0.diff < $1.diff }
        nudges.sort {
            Double($0.daysSinceContact) / Double($0.cadenceDays) > Double($1.daysSinceContact) / Double($1.cadenceDays)
        }
    }

    var summary: String {
        var parts: [String] = []
        if !overdue.isEmpty { parts.append(plural(overdue.count, "overdue reminder")) }
        if !week.isEmpty { parts.append("\(plural(week.count, "thing")) in the next week") }
        if !nudges.isEmpty { parts.append("\(nudges.count) \(nudges.count == 1 ? "person" : "people") to reach out to") }
        guard let last = parts.last else { return "Nothing needs you right now. You're all caught up." }
        if parts.count == 1 { return "You have \(last)." }
        return "You have \(parts.dropLast().joined(separator: ", ")) and \(last)."
    }
}
