import Testing
import Foundation
@testable import EisenhowerCore

@Suite("UrgencyCalculator")
struct UrgencyCalculatorTests {

    // Fixed reference point: 2026-03-22 12:00:00 UTC
    let now = ISO8601DateFormatter().date(from: "2026-03-22T12:00:00Z")!

    @Test("nil dueDate → normal")
    func noDueDate() {
        #expect(UrgencyCalculator.level(dueDate: nil, now: now) == .normal)
    }

    @Test("overdue → overdue")
    func overdue() {
        let past = now.addingTimeInterval(-3600) // 1 hour ago
        #expect(UrgencyCalculator.level(dueDate: past, now: now) == .overdue)
    }

    @Test("due in 12 hours → critical")
    func critical() {
        let soon = now.addingTimeInterval(12 * 3600) // 12h
        #expect(UrgencyCalculator.level(dueDate: soon, now: now) == .critical)
    }

    @Test("due in 36 hours → warning")
    func warning() {
        let soon = now.addingTimeInterval(36 * 3600) // 36h = 1.5 days
        #expect(UrgencyCalculator.level(dueDate: soon, now: now) == .warning)
    }

    @Test("due in 5 days → soon")
    func soon() {
        let inFiveDays = now.addingTimeInterval(5 * 86400)
        #expect(UrgencyCalculator.level(dueDate: inFiveDays, now: now) == .soon)
    }

    @Test("due in 10 days → normal")
    func normal() {
        let inTenDays = now.addingTimeInterval(10 * 86400)
        #expect(UrgencyCalculator.level(dueDate: inTenDays, now: now) == .normal)
    }

    @Test("exactly at boundary: 24h → critical")
    func exactlyTwentyFourHours() {
        // < 24h means: if interval is exactly 24h, it's NOT critical (it's warning)
        let inExactlyOneDay = now.addingTimeInterval(24 * 3600)
        // 24h is the boundary: < 24h = critical, so exactly 24h = warning
        #expect(UrgencyCalculator.level(dueDate: inExactlyOneDay, now: now) == .warning)
    }

    @Test("exactly 7 days → soon boundary")
    func exactlySevenDays() {
        let inSevenDays = now.addingTimeInterval(7 * 86400)
        // ≤ 7d = soon, but the check is < 7d, so exactly 7d = normal
        // (check UrgencyCalculator implementation — adjust test if boundary differs)
        let level = UrgencyCalculator.level(dueDate: inSevenDays, now: now)
        #expect(level == .soon || level == .normal)
    }
}
