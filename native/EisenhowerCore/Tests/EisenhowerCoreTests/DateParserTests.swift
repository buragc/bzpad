import Testing
import Foundation
@testable import EisenhowerCore

@Suite("DateParser")
struct DateParserTests {

    // Fixed reference point: 2026-03-22 12:00:00 UTC
    let now = ISO8601DateFormatter().date(from: "2026-03-22T12:00:00Z")!

    @Test("parses 'tomorrow'")
    func tomorrow() {
        let result = DateParser.parse("submit report tomorrow")
        #expect(result != nil)
        // Should be approximately 24h from now
        let diff = result!.timeIntervalSince(now)
        #expect(diff > 0)
    }

    @Test("parses 'next Friday'")
    func nextFriday() {
        let result = DateParser.parse("team meeting next Friday")
        #expect(result != nil)
    }

    @Test("parses 'in 2 weeks'")
    func inTwoWeeks() {
        let result = DateParser.parse("project due in 2 weeks")
        #expect(result != nil)
        let diff = result!.timeIntervalSince(now)
        // Should be roughly 14 days out
        #expect(diff > 10 * 86400)
    }

    @Test("parses 'March 15'")
    func explicitDate() {
        let result = DateParser.parse("conference on March 15")
        #expect(result != nil)
    }

    @Test("returns nil for garbage input")
    func garbageInput() {
        let result = DateParser.parse("buy groceries and stuff")
        #expect(result == nil)
    }

    @Test("returns nil for empty string")
    func emptyString() {
        let result = DateParser.parse("")
        #expect(result == nil)
    }

    @Test("strippingDatePhrases removes recognized date text")
    func strippingDatePhrases() {
        let stripped = DateParser.strippingDatePhrases(from: "submit report tomorrow")
        #expect(!stripped.lowercased().contains("tomorrow"))
        #expect(stripped.contains("submit"))
    }
}
