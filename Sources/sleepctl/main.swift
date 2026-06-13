import ArgumentParser
import Foundation
import SleepDaemonCore

@main
struct SleepControl: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "sleepctl",
        abstract: "Control the SleepDaemon user LaunchAgent.",
        subcommands: [
            Off.self,
            On.self,
            For.self,
            Until.self,
            Cancel.self,
            List.self,
            Status.self,
            Windows.self,
            Daemon.self
        ]
    )
}

struct ReasonOptions: ParsableArguments {
    @Option(name: .long, help: "Reason shown in power assertions.")
    var reason: String?
}

struct Off: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Prevent system and display sleep until cancelled.")

    @OptionGroup var reasonOptions: ReasonOptions

    func run() throws {
        let task = try requireTask(send(.createTask(TaskRequest(kind: .indefinite, reason: reasonOptions.reason))))
        printTask(task)
    }
}

struct On: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Cancel all SleepDaemon tasks and allow normal sleep.")

    func run() throws {
        let result = try requireCancel(send(.cancel(CancelRequest(all: true))))
        print("cancelled \(result.cancelled) task(s)")
    }
}

struct For: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "for", abstract: "Prevent sleep for a duration.")

    @Argument(help: "Duration such as 30s, 10m, or 1h.")
    var duration: String

    @OptionGroup var reasonOptions: ReasonOptions

    func run() throws {
        let seconds = try DurationParser.parse(duration)
        let task = try requireTask(send(.createTask(TaskRequest(kind: .timed, reason: reasonOptions.reason, durationSeconds: seconds))))
        printTask(task)
    }
}

struct Until: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Prevent sleep until a target disappears.",
        subcommands: [UntilPID.self, UntilBundle.self, UntilWindow.self]
    )
}

struct UntilPID: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "pid", abstract: "Prevent sleep until a process exits.")

    @Argument var pid: Int32
    @OptionGroup var reasonOptions: ReasonOptions

    func run() throws {
        let task = try requireTask(send(.createTask(TaskRequest(kind: .pid, reason: reasonOptions.reason, target: TaskTarget(pid: pid)))))
        printTask(task)
    }
}

struct UntilBundle: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "bundle", abstract: "Prevent sleep until a bundle is no longer running.")

    @Argument(help: "Application bundle identifier.")
    var bundleIdentifier: String

    @OptionGroup var reasonOptions: ReasonOptions

    func run() throws {
        let task = try requireTask(send(.createTask(TaskRequest(kind: .bundle, reason: reasonOptions.reason, target: TaskTarget(bundleIdentifier: bundleIdentifier)))))
        printTask(task)
    }
}

struct UntilWindow: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "window", abstract: "Prevent sleep until a visible window closes.")

    @Argument(help: "CGWindowID from 'sleepctl windows'.")
    var windowID: UInt32

    @OptionGroup var reasonOptions: ReasonOptions

    func run() throws {
        let task = try requireTask(send(.createTask(TaskRequest(kind: .window, reason: reasonOptions.reason, target: TaskTarget(windowID: windowID)))))
        printTask(task)
    }
}

struct Cancel: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Cancel a task by id, or all tasks.")

    @Argument(help: "Task UUID or 'all'.")
    var id: String

    func run() throws {
        let request: CancelRequest
        if id.lowercased() == "all" {
            request = CancelRequest(all: true)
        } else if let uuid = UUID(uuidString: id) {
            request = CancelRequest(id: uuid)
        } else {
            throw ValidationError("expected a task UUID or 'all'")
        }

        let result = try requireCancel(send(.cancel(request)))
        print("cancelled \(result.cancelled) task(s)")
    }
}

struct List: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "List active sleep tasks.")

    func run() throws {
        let tasks = try requireTasks(send(.listTasks))
        if tasks.isEmpty {
            print("no active tasks")
            return
        }
        for task in tasks {
            printTask(task)
        }
    }
}

struct Status: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Show current SleepDaemon state.")

    func run() throws {
        let status = try requireStatus(send(.status))
        print("sleep prevented: \(status.sleepPrevented ? "yes" : "no")")
        print("active tasks: \(status.activeTaskCount)")
        print("assertions: \(status.activeAssertionTypes.isEmpty ? "none" : status.activeAssertionTypes.joined(separator: ", "))")
        print("started: \(formatDate(status.daemonStartedAt))")
        print("version: \(status.version)")
    }
}

struct Windows: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "List visible windows that can be used with 'sleepctl until window'.")

    func run() throws {
        let windows = try requireWindows(send(.listWindows))
        if windows.isEmpty {
            print("no visible windows")
            return
        }
        for window in windows {
            let title = window.title ?? "-"
            let bundle = window.bundleIdentifier ?? "-"
            print("\(window.windowID)\tpid=\(window.ownerPID)\t\(window.ownerName)\t\(bundle)\t\(title)")
        }
    }
}

struct Daemon: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Install and control the user LaunchAgent.",
        subcommands: [Install.self, Uninstall.self, Start.self, Stop.self, DaemonStatus.self]
    )

    struct Install: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Install the user LaunchAgent plist.")

        @Option(help: "Path to the sleepd executable.")
        var daemonPath: String?

        func run() throws {
            let path = daemonPath ?? LaunchAgentManager.daemonPath(relativeTo: CommandLine.arguments[0])
            try LaunchAgentManager.install(daemonPath: path)
            print("installed \(LaunchAgentManager.plistPath)")
        }
    }

    struct Uninstall: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Stop and remove the user LaunchAgent plist.")

        func run() throws {
            _ = try runLaunchctl(["bootout", "gui/\(getuid())/\(sleepDaemonLaunchAgentLabel)"], allowFailure: true)
            try LaunchAgentManager.uninstall()
            print("removed \(LaunchAgentManager.plistPath)")
        }
    }

    struct Start: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Load and start the user LaunchAgent.")

        func run() throws {
            try runLaunchctl(["bootstrap", "gui/\(getuid())", LaunchAgentManager.plistPath])
            try runLaunchctl(["kickstart", "-k", "gui/\(getuid())/\(sleepDaemonLaunchAgentLabel)"])
            print("started \(sleepDaemonLaunchAgentLabel)")
        }
    }

    struct Stop: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Stop the user LaunchAgent.")

        func run() throws {
            try runLaunchctl(["bootout", "gui/\(getuid())/\(sleepDaemonLaunchAgentLabel)"])
            print("stopped \(sleepDaemonLaunchAgentLabel)")
        }
    }

    struct DaemonStatus: ParsableCommand {
        static let configuration = CommandConfiguration(commandName: "status", abstract: "Print launchd status for the user LaunchAgent.")

        func run() throws {
            let output = try runLaunchctl(["print", "gui/\(getuid())/\(sleepDaemonLaunchAgentLabel)"])
            print(output, terminator: output.hasSuffix("\n") ? "" : "\n")
        }
    }
}

private func send(_ request: DaemonRequest) throws -> DaemonResponse {
    try SleepDaemonClient().send(request)
}

private func requireTask(_ response: DaemonResponse) throws -> SleepTask {
    switch response {
    case .task(let task):
        return task
    case .error(let message):
        throw ValidationError(message)
    default:
        throw SleepDaemonError.unexpectedResponse
    }
}

private func requireTasks(_ response: DaemonResponse) throws -> [SleepTask] {
    switch response {
    case .tasks(let tasks):
        return tasks
    case .error(let message):
        throw ValidationError(message)
    default:
        throw SleepDaemonError.unexpectedResponse
    }
}

private func requireCancel(_ response: DaemonResponse) throws -> CancelResult {
    switch response {
    case .cancel(let result):
        return result
    case .error(let message):
        throw ValidationError(message)
    default:
        throw SleepDaemonError.unexpectedResponse
    }
}

private func requireStatus(_ response: DaemonResponse) throws -> SleepStatus {
    switch response {
    case .status(let status):
        return status
    case .error(let message):
        throw ValidationError(message)
    default:
        throw SleepDaemonError.unexpectedResponse
    }
}

private func requireWindows(_ response: DaemonResponse) throws -> [WindowInfo] {
    switch response {
    case .windows(let windows):
        return windows
    case .error(let message):
        throw ValidationError(message)
    default:
        throw SleepDaemonError.unexpectedResponse
    }
}

private func printTask(_ task: SleepTask) {
    var fields = [
        task.id.uuidString,
        task.kind.rawValue,
        "reason='\(task.reason)'",
        "created=\(formatDate(task.createdAt))"
    ]
    if let expiresAt = task.expiresAt {
        fields.append("expires=\(formatDate(expiresAt))")
    }
    if let pid = task.target?.pid {
        fields.append("pid=\(pid)")
    }
    if let bundleIdentifier = task.target?.bundleIdentifier {
        fields.append("bundle=\(bundleIdentifier)")
    }
    if let windowID = task.target?.windowID {
        fields.append("window=\(windowID)")
    }
    print(fields.joined(separator: "\t"))
}

private func formatDate(_ date: Date) -> String {
    ISO8601DateFormatter().string(from: date)
}

@discardableResult
private func runLaunchctl(_ arguments: [String], allowFailure: Bool = false) throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
    process.arguments = arguments

    let output = Pipe()
    let error = Pipe()
    process.standardOutput = output
    process.standardError = error

    try process.run()
    process.waitUntilExit()

    let outputData = output.fileHandleForReading.readDataToEndOfFile()
    let errorData = error.fileHandleForReading.readDataToEndOfFile()
    let outputText = String(data: outputData, encoding: .utf8) ?? ""
    let errorText = String(data: errorData, encoding: .utf8) ?? ""

    if process.terminationStatus != 0 && !allowFailure {
        throw ValidationError(errorText.isEmpty ? "launchctl failed with status \(process.terminationStatus)" : errorText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    return outputText.isEmpty ? errorText : outputText
}
