import Testing
import SleepDaemonCore

@Test func parsesSecondsMinutesAndHours() throws {
    #expect(try DurationParser.parse("30s") == 30)
    #expect(try DurationParser.parse("10m") == 600)
    #expect(try DurationParser.parse("1h") == 3600)
    #expect(try DurationParser.parse("2") == 2)
}

@Test func rejectsInvalidDurations() {
    #expect(throws: (any Error).self) { try DurationParser.parse("") }
    #expect(throws: (any Error).self) { try DurationParser.parse("0s") }
    #expect(throws: (any Error).self) { try DurationParser.parse("ten minutes") }
}
