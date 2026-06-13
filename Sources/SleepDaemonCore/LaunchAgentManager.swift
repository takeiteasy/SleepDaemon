import Foundation

public enum LaunchAgentManager {
    public static func daemonPath(relativeTo executablePath: String) -> String {
        let executableURL = URL(fileURLWithPath: executablePath)
        let sibling = executableURL.deletingLastPathComponent().appendingPathComponent("sleepd")
        if FileManager.default.isExecutableFile(atPath: sibling.path) {
            return sibling.path
        }
        return FileManager.default.currentDirectoryPath + "/.build/debug/sleepd"
    }

    public static func install(daemonPath: String) throws {
        let launchAgentURL = SleepDaemonPaths.launchAgentURL
        try FileManager.default.createDirectory(at: launchAgentURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        let plist: [String: Any] = [
            "Label": sleepDaemonLaunchAgentLabel,
            "MachServices": [sleepDaemonMachServiceName: true],
            "ProgramArguments": [daemonPath],
            "RunAtLoad": true,
            "KeepAlive": true,
            "StandardOutPath": "\(NSHomeDirectory())/Library/Logs/SleepDaemon.log",
            "StandardErrorPath": "\(NSHomeDirectory())/Library/Logs/SleepDaemon.err.log"
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: launchAgentURL, options: [.atomic])
    }

    public static func uninstall() throws {
        let url = SleepDaemonPaths.launchAgentURL
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    public static var plistPath: String {
        SleepDaemonPaths.launchAgentURL.path
    }
}
