import Foundation

public final class TaskStore {
    private let url: URL

    public init(url: URL = SleepDaemonPaths.taskStoreURL) {
        self.url = url
    }

    public func load() throws -> [SleepTask] {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return []
        }
        let data = try Data(contentsOf: url)
        return try SleepDaemonCoding.decoder.decode([SleepTask].self, from: data)
    }

    public func save(_ tasks: [SleepTask]) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try SleepDaemonCoding.encoder.encode(tasks)
        try data.write(to: url, options: [.atomic])
    }
}
