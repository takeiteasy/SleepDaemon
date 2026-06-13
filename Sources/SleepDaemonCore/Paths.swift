import Foundation

public enum SleepDaemonPaths {
    public static var applicationSupportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("SleepDaemon", isDirectory: true)
    }

    public static var taskStoreURL: URL {
        applicationSupportDirectory.appendingPathComponent("tasks.json")
    }

    public static var launchAgentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(sleepDaemonLaunchAgentLabel).plist")
    }
}
