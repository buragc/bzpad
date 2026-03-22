import Foundation

/// Computes urgency level from a task's due date.
/// Boundaries match the React prototype and the requirements spec (FR-2.2.1).
public enum UrgencyCalculator {

    /// Returns the urgency level for a given due date relative to `now`.
    /// Pass `now` explicitly for testability (avoids Date() in hot paths).
    public static func level(dueDate: Date?, now: Date = Date()) -> UrgencyLevel {
        guard let dueDate else { return .normal }

        let diffSeconds = dueDate.timeIntervalSince(now)
        let diffHours   = diffSeconds / 3600
        let diffDays    = diffHours / 24

        if diffSeconds < 0          { return .overdue }  // past due
        if diffHours   < 24         { return .critical } // < 24 h
        if diffDays    <= 2         { return .warning }  // 1–2 days
        if diffDays    <= 7         { return .soon }     // 3–7 days
        return .normal                                   // > 7 days
    }
}
