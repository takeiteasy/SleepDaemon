import Foundation

public let sleepDaemonMachServiceName = "com.takeiteasy.SleepDaemon"
public let sleepDaemonLaunchAgentLabel = "com.takeiteasy.SleepDaemon"

public enum SleepTaskKind: String, Codable, Sendable {
    case indefinite
    case timed
    case pid
    case bundle
    case window
}

public enum SleepTaskState: String, Codable, Sendable {
    case active
    case completed
}

public struct TaskTarget: Codable, Equatable, Sendable {
    public var pid: Int32?
    public var bundleIdentifier: String?
    public var windowID: UInt32?

    public init(pid: Int32? = nil, bundleIdentifier: String? = nil, windowID: UInt32? = nil) {
        self.pid = pid
        self.bundleIdentifier = bundleIdentifier
        self.windowID = windowID
    }
}

public struct SleepTask: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var kind: SleepTaskKind
    public var reason: String
    public var createdAt: Date
    public var expiresAt: Date?
    public var target: TaskTarget?
    public var state: SleepTaskState

    public init(
        id: UUID = UUID(),
        kind: SleepTaskKind,
        reason: String,
        createdAt: Date = Date(),
        expiresAt: Date? = nil,
        target: TaskTarget? = nil,
        state: SleepTaskState = .active
    ) {
        self.id = id
        self.kind = kind
        self.reason = reason
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.target = target
        self.state = state
    }
}

public struct TaskRequest: Codable, Equatable, Sendable {
    public var kind: SleepTaskKind
    public var reason: String?
    public var durationSeconds: TimeInterval?
    public var target: TaskTarget?

    public init(
        kind: SleepTaskKind, reason: String? = nil, durationSeconds: TimeInterval? = nil,
        target: TaskTarget? = nil
    ) {
        self.kind = kind
        self.reason = reason
        self.durationSeconds = durationSeconds
        self.target = target
    }
}

public struct CancelRequest: Codable, Equatable, Sendable {
    public var id: UUID?
    public var all: Bool

    public init(id: UUID? = nil, all: Bool = false) {
        self.id = id
        self.all = all
    }
}

public struct CancelResult: Codable, Equatable, Sendable {
    public var cancelled: Int

    public init(cancelled: Int) {
        self.cancelled = cancelled
    }
}

public struct SleepStatus: Codable, Equatable, Sendable {
    public var sleepPrevented: Bool
    public var activeAssertionTypes: [String]
    public var activeTaskCount: Int
    public var daemonStartedAt: Date
    public var version: String

    public init(
        sleepPrevented: Bool,
        activeAssertionTypes: [String],
        activeTaskCount: Int,
        daemonStartedAt: Date,
        version: String
    ) {
        self.sleepPrevented = sleepPrevented
        self.activeAssertionTypes = activeAssertionTypes
        self.activeTaskCount = activeTaskCount
        self.daemonStartedAt = daemonStartedAt
        self.version = version
    }
}

public struct WindowInfo: Codable, Equatable, Sendable {
    public var windowID: UInt32
    public var ownerPID: Int32
    public var ownerName: String
    public var bundleIdentifier: String?
    public var title: String?

    public init(
        windowID: UInt32, ownerPID: Int32, ownerName: String, bundleIdentifier: String?,
        title: String?
    ) {
        self.windowID = windowID
        self.ownerPID = ownerPID
        self.ownerName = ownerName
        self.bundleIdentifier = bundleIdentifier
        self.title = title
    }
}

public enum DaemonRequest: Codable, Equatable, Sendable {
    case status
    case listTasks
    case createTask(TaskRequest)
    case cancel(CancelRequest)
    case listWindows

    private enum CodingKeys: String, CodingKey {
        case action
        case task
        case cancel
    }

    private enum Action: String, Codable {
        case status
        case listTasks
        case createTask
        case cancel
        case listWindows
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Action.self, forKey: .action) {
        case .status:
            self = .status
        case .listTasks:
            self = .listTasks
        case .createTask:
            self = .createTask(try container.decode(TaskRequest.self, forKey: .task))
        case .cancel:
            self = .cancel(try container.decode(CancelRequest.self, forKey: .cancel))
        case .listWindows:
            self = .listWindows
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .status:
            try container.encode(Action.status, forKey: .action)
        case .listTasks:
            try container.encode(Action.listTasks, forKey: .action)
        case .createTask(let task):
            try container.encode(Action.createTask, forKey: .action)
            try container.encode(task, forKey: .task)
        case .cancel(let cancel):
            try container.encode(Action.cancel, forKey: .action)
            try container.encode(cancel, forKey: .cancel)
        case .listWindows:
            try container.encode(Action.listWindows, forKey: .action)
        }
    }
}

public enum DaemonResponse: Codable, Equatable, Sendable {
    case status(SleepStatus)
    case tasks([SleepTask])
    case task(SleepTask)
    case cancel(CancelResult)
    case windows([WindowInfo])
    case error(String)

    private enum CodingKeys: String, CodingKey {
        case kind
        case status
        case tasks
        case task
        case cancel
        case windows
        case message
    }

    private enum Kind: String, Codable {
        case status
        case tasks
        case task
        case cancel
        case windows
        case error
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .status:
            self = .status(try container.decode(SleepStatus.self, forKey: .status))
        case .tasks:
            self = .tasks(try container.decode([SleepTask].self, forKey: .tasks))
        case .task:
            self = .task(try container.decode(SleepTask.self, forKey: .task))
        case .cancel:
            self = .cancel(try container.decode(CancelResult.self, forKey: .cancel))
        case .windows:
            self = .windows(try container.decode([WindowInfo].self, forKey: .windows))
        case .error:
            self = .error(try container.decode(String.self, forKey: .message))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .status(let status):
            try container.encode(Kind.status, forKey: .kind)
            try container.encode(status, forKey: .status)
        case .tasks(let tasks):
            try container.encode(Kind.tasks, forKey: .kind)
            try container.encode(tasks, forKey: .tasks)
        case .task(let task):
            try container.encode(Kind.task, forKey: .kind)
            try container.encode(task, forKey: .task)
        case .cancel(let result):
            try container.encode(Kind.cancel, forKey: .kind)
            try container.encode(result, forKey: .cancel)
        case .windows(let windows):
            try container.encode(Kind.windows, forKey: .kind)
            try container.encode(windows, forKey: .windows)
        case .error(let message):
            try container.encode(Kind.error, forKey: .kind)
            try container.encode(message, forKey: .message)
        }
    }
}
