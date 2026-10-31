import SwiftUI
import UIKit

enum Theme {
    static let accent = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.55, green: 0.76, blue: 0.66, alpha: 1)
            : UIColor(red: 0.24, green: 0.42, blue: 0.35, alpha: 1)
    })
    static let due = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.91, green: 0.56, blue: 0.48, alpha: 1)
            : UIColor(red: 0.66, green: 0.27, blue: 0.18, alpha: 1)
    })
}

/// Initials inside a ring that drains as time passes since your last catch-up.
/// When it's time to reach out, the ring turns into a dashed warning color.
struct WarmthAvatar: View {
    let person: Person
    var size: CGFloat = 44

    var body: some View {
        let hasRing = person.cadenceDays > 0
        ZStack {
            if hasRing {
                if person.nudgeDue {
                    Circle().stroke(Theme.due, style: StrokeStyle(lineWidth: 3, dash: [3, 3.5]))
                } else {
                    Circle().stroke(Color.secondary.opacity(0.25), lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: max(0.01, person.warmth))
                        .stroke(Theme.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
            }
            Circle()
                .fill(Color(hue: person.hue, saturation: 0.28, brightness: 0.93))
                .padding(hasRing ? size * 0.12 : size * 0.04)
            Text(person.initials)
                .font(.system(size: size * 0.34, weight: .regular, design: .serif))
                .foregroundStyle(Color(hue: person.hue, saturation: 0.55, brightness: 0.35))
        }
        .frame(width: size, height: size)
        .padding(1.5)
        .accessibilityHidden(true)
    }
}

struct PersonRow: View {
    let person: Person

    var body: some View {
        HStack(spacing: 12) {
            WarmthAvatar(person: person, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(person.name).font(.body.weight(.semibold))
                Text(person.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(person.nudgeDue ? Theme.due : Color.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

/// A reminder with a tappable check circle. Pass `person` to show their name
/// and make the row open their page (used on the Today tab).
struct ReminderRow: View {
    let reminder: Reminder
    var person: Person? = nil

    var body: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation {
                    reminder.done.toggle()
                    reminder.doneAt = reminder.done ? .now : nil
                }
            } label: {
                Image(systemName: reminder.done ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(reminder.done ? Theme.accent : Color.secondary)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(reminder.done ? "Mark as not done" : "Mark as done")

            if let person {
                NavigationLink(value: person) { content(person) }
            } else {
                content(nil)
            }
        }
    }

    @ViewBuilder
    private func content(_ person: Person?) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(reminder.text)
                    .strikethrough(reminder.done)
                    .foregroundStyle(reminder.done ? Color.secondary : Color.primary)
                if let person {
                    Text(person.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                }
            }
            Spacer(minLength: 8)
            if let due = reminder.due {
                let diff = Day.between(.now, due)
                Text(reminder.done ? due.formatted(.dateTime.month(.abbreviated).day()) : Day.relative(diff, date: due))
                    .font(.subheadline)
                    .foregroundStyle(!reminder.done && diff < 0 ? Theme.due : Color.secondary)
            }
        }
    }
}

struct EventRow: View {
    let event: UpcomingEvent

    var body: some View {
        NavigationLink(value: event.person) {
            HStack(spacing: 12) {
                Image(systemName: event.isBirthday ? "gift" : "calendar")
                    .foregroundStyle(Theme.accent)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                    Text(event.person.name).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Text(Day.relative(event.diff, date: event.date))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct TimelineRow: View {
    let entry: TimelineEntry

    var body: some View {
        switch entry.kind {
        case .reminder(let r): ReminderRow(reminder: r, person: entry.person)
        case .event(let e): EventRow(event: e)
        }
    }
}

struct NudgeRow: View {
    let person: Person

    var body: some View {
        HStack(spacing: 12) {
            NavigationLink(value: person) {
                HStack(spacing: 12) {
                    WarmthAvatar(person: person, size: 40)
                    Text(person.lastContact == nil
                         ? "You haven't logged a catch-up with \(person.firstName) yet."
                         : "It's been \(Day.span(person.daysSinceContact)) since you caught up with \(person.firstName).")
                }
            }
            Button("Caught up") {
                withAnimation { person.lastContact = .now }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }
}

struct NoteRow: View {
    let note: Note

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(note.text)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 8) {
                if note.pinned {
                    Image(systemName: "pin.fill").font(.caption).foregroundStyle(Theme.accent)
                        .accessibilityLabel("Pinned")
                }
                if note.isCatchUp {
                    Text("Catch-up")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(Theme.accent.opacity(0.15), in: Capsule())
                        .foregroundStyle(Theme.accent)
                }
                Text(note.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
