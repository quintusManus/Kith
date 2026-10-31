import Foundation
import SwiftData
import UserNotifications

/// Schedules local notifications for reminders, birthdays, important dates,
/// and check-in nudges. iOS allows 64 pending notifications per app,
/// so this keeps the soonest 60 and refreshes them whenever you leave the app.
@MainActor
final class NotificationManager {
    static let shared = NotificationManager()
    private let center = UNUserNotificationCenter.current()

    func requestAuthorization() async {
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }

    func reschedule(context: ModelContext) {
        let people = (try? context.fetch(FetchDescriptor<Person>())) ?? []
        let now = Date.now
        let cal = Calendar.current
        var items: [(date: Date, id: String, title: String, body: String)] = []

        func at(_ hour: Int, on day: Date) -> Date? {
            cal.date(bySettingHour: hour, minute: 0, second: 0, of: day)
        }

        for p in people {
            for r in p.reminders ?? [] where !r.done {
                guard let due = r.due, let fire = at(9, on: due), fire > now else { continue }
                items.append((fire, "rem-\(r.id)", p.name, r.text))
            }

            if let nb = p.nextBirthday, let fire = at(9, on: nb), fire > now {
                let body = p.turningAge.map { "They're turning \($0) today." } ?? "It's today."
                items.append((fire, "bday-\(p.id)", "\(p.firstName)'s birthday", body))
            }

            for k in p.keyDates ?? [] {
                guard let nd = k.nextOccurrence, let fire = at(9, on: nd), fire > now else { continue }
                items.append((fire, "date-\(k.id)", "\(k.label) for \(p.firstName)", "It's today."))
            }

            if let next = p.nextCheckIn {
                var fire = at(10, on: next) ?? next
                if fire <= now, let tomorrow = cal.date(byAdding: .day, value: 1, to: now) {
                    fire = at(10, on: tomorrow) ?? tomorrow
                }
                let body = p.lastContact == nil
                    ? "Time to check in with \(p.firstName)."
                    : "It's been a while since you caught up with \(p.firstName)."
                items.append((fire, "nudge-\(p.id)", "Reach out to \(p.firstName)", body))
            }
        }

        center.removeAllPendingNotificationRequests()
        for item in items.sorted(by: { $0.date < $1.date }).prefix(60) {
            let content = UNMutableNotificationContent()
            content.title = item.title
            content.body = item.body
            content.sound = .default
            let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: item.date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            center.add(UNNotificationRequest(identifier: item.id, content: content, trigger: trigger))
        }
    }
}
