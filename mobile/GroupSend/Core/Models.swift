import Foundation

// MARK: - User

struct UserProfile: Identifiable, Decodable, Hashable {
    let id: String
    let name: String
    let avatarColor: String
}

// MARK: - Group

// Basic group returned by GET /groups (list endpoint — no members included)
struct GroupModel: Identifiable, Decodable, Hashable {
    let id: String
    let name: String
    let gymName: String
    let description: String?
    let inviteCode: String
    // Only populated by GET /groups/:id (detail endpoint)
    let members: [GroupMembership]?
}

// The join table row returned when a group includes its members
struct GroupMembership: Decodable, Hashable {
    let userId: String
    let user: UserProfile
}

struct GroupListResponse: Decodable {
    let groups: [GroupModel]
}

// MARK: - Sessions

// Session as returned by GET /sessions — includes the user who logged it
struct SessionRecord: Identifiable, Decodable {
    let id: String
    let userId: String
    let groupId: String
    let climbedAt: Date
    let user: SessionUser
}

struct SessionUser: Decodable {
    let id: String
    let name: String
    let avatarColor: String
}

struct SessionsResponse: Decodable {
    let sessions: [SessionRecord]
}

// MARK: - Invite

// Public group preview for the invite landing screen (no auth required)
struct InviteInfo: Decodable {
    let name: String
    let gymName: String
    let description: String?
    let memberCount: Int
}

// MARK: - Column-stack view models

// One column in the column-stack chart = one day.
// `climbers` is the ordered list of people who logged a session that day.
struct DayColumn: Identifiable {
    let id: String   // "YYYY-MM-DD" — unique per day
    let date: Date
    let climbers: [ClimberDot]
}

// A single dot in the column-stack.
// Stores the hex string so the model layer stays free of SwiftUI.
struct ClimberDot: Identifiable {
    let id: String      // userId
    let hexColor: String
    let name: String
}

// MARK: - Helpers

extension Array where Element == SessionRecord {
    // Build the last N calendar days as DayColumn values from a flat session list.
    // Sessions are pre-grouped by day; climbers within each day retain their original order.
    func toDayColumns(days count: Int, timeZone: TimeZone = .current) -> [DayColumn] {
        var cal = Calendar.current
        cal.timeZone = timeZone

        let today = cal.startOfDay(for: Date())
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        formatter.timeZone = timeZone

        // Build a lookup: "YYYY-MM-DD" → [ClimberDot]
        var byDay: [String: [ClimberDot]] = [:]
        for session in self {
            let key = formatter.string(from: session.climbedAt)
            let dot = ClimberDot(id: session.userId, hexColor: session.user.avatarColor, name: session.user.name)
            // Dedup: one dot per user per day (API enforces this, but guard at view layer too)
            if !(byDay[key]?.contains(where: { $0.id == dot.id }) ?? false) {
                byDay[key, default: []].append(dot)
            }
        }

        return (0..<count).reversed().map { offset in
            let date = cal.date(byAdding: .day, value: -offset, to: today)!
            let key = formatter.string(from: date)
            return DayColumn(id: key, date: date, climbers: byDay[key] ?? [])
        }
    }
}
