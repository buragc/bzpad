import Testing
@testable import EisenhowerCore

@Suite("TagExtractor")
struct TagExtractorTests {

    @Test("extracts single #hashtag")
    func singleHashtag() {
        let tags = TagExtractor.extract(from: "fix #bug in login")
        #expect(tags.contains("bug"))
    }

    @Test("extracts multiple #hashtags")
    func multipleHashtags() {
        let tags = TagExtractor.extract(from: "write #docs for #api")
        #expect(tags.contains("docs"))
        #expect(tags.contains("api"))
    }

    @Test("extracts keyword tags alongside hashtags")
    func keywordTags() {
        let tags = TagExtractor.extract(from: "urgent #work task")
        #expect(tags.contains("work"))
        #expect(tags.contains("urgent"))
    }

    @Test("no duplicates")
    func noDuplicates() {
        // "urgent" appears as both a hashtag and a keyword
        let tags = TagExtractor.extract(from: "urgent #urgent task")
        let count = tags.filter { $0 == "urgent" }.count
        #expect(count == 1)
    }

    @Test("returns empty array for text with no tags or keywords")
    func emptyResult() {
        let tags = TagExtractor.extract(from: "buy milk")
        // "buy milk" has no keywords from either list
        #expect(tags.isEmpty)
    }

    @Test("tags are lowercase")
    func lowercase() {
        let tags = TagExtractor.extract(from: "Review #Work item")
        #expect(tags.allSatisfy { $0 == $0.lowercased() })
    }

    @Test("strippingHashtags removes # tags from text")
    func strippingHashtags() {
        let clean = TagExtractor.strippingHashtags(from: "fix #bug and #ui")
        #expect(!clean.contains("#bug"))
        #expect(!clean.contains("#ui"))
        #expect(clean.contains("fix"))
    }
}
