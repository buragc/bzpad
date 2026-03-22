import Testing
@testable import EisenhowerCore

@Suite("QuadrantDetector")
struct QuadrantDetectorTests {

    @Test("urgent keyword alone → Delegate (Q3)")
    func urgentOnly() {
        #expect(QuadrantDetector.detect(from: "send the report urgent") == .delegate)
    }

    @Test("important keyword alone → Schedule (Q2)")
    func importantOnly() {
        #expect(QuadrantDetector.detect(from: "review the strategic roadmap") == .schedule)
    }

    @Test("both urgent + important → Do First (Q1)")
    func urgentAndImportant() {
        #expect(QuadrantDetector.detect(from: "urgent milestone review") == .doFirst)
    }

    @Test("no keywords → Eliminate (Q4)")
    func noKeywords() {
        #expect(QuadrantDetector.detect(from: "buy groceries") == .eliminate)
    }

    @Test("critical alone → Do First (Q1) — keyword in both lists")
    func criticalInBothLists() {
        // "critical" is in BOTH urgentKeywords AND importantKeywords → Q1
        #expect(QuadrantDetector.detect(from: "critical bug in production") == .doFirst)
    }

    @Test("case insensitive — URGENT")
    func caseInsensitive() {
        #expect(QuadrantDetector.detect(from: "URGENT task") == .delegate)
    }

    @Test("empty string → Eliminate (Q4)")
    func emptyString() {
        #expect(QuadrantDetector.detect(from: "") == .eliminate)
    }

    @Test("'due' keyword → Delegate (Q3)")
    func dueKeyword() {
        #expect(QuadrantDetector.detect(from: "submit assignment due") == .delegate)
    }

    @Test("'goal' keyword → Schedule (Q2)")
    func goalKeyword() {
        #expect(QuadrantDetector.detect(from: "fitness goal for the year") == .schedule)
    }

    @Test("'deadline' + 'milestone' → Do First (Q1)")
    func deadlineAndMilestone() {
        #expect(QuadrantDetector.detect(from: "deadline for milestone delivery") == .doFirst)
    }
}
