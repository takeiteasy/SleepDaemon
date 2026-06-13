import Foundation
import Testing
import SleepDaemonCore

@Test func taskStoreRoundTrip() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let url = directory.appendingPathComponent("tasks.json")
    let store = TaskStore(url: url)
    let tasks = [
        SleepTask(kind: .indefinite, reason: "test"),
        SleepTask(kind: .timed, reason: "timer", expiresAt: Date().addingTimeInterval(30))
    ]

    try store.save(tasks)
    let loaded = try store.load()
    #expect(loaded.count == 2)
    #expect(loaded[0].kind == .indefinite)
    #expect(loaded[0].reason == "test")
    #expect(loaded[1].kind == .timed)
    #expect(loaded[1].reason == "timer")
    #expect(abs(loaded[1].expiresAt!.timeIntervalSince(tasks[1].expiresAt!)) < 1)
}
