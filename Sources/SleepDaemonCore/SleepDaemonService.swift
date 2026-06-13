import Foundation

public final class SleepDaemonService: @unchecked Sendable {
    private let lock = NSRecursiveLock()
    private let store: TaskStore
    private let assertionManager: PowerAssertionManager
    private let startedAt = Date()
    private let version = "0.1.0"
    private var tasks: [SleepTask]

    public init(store: TaskStore = TaskStore(), assertionManager: PowerAssertionManager = PowerAssertionManager()) {
        self.store = store
        self.assertionManager = assertionManager
        self.tasks = (try? store.load()) ?? []
        pruneLocked(now: Date())
        persistLocked()
        refreshAssertionsLocked()
    }

    public func handle(_ request: DaemonRequest) -> DaemonResponse {
        lock.lock()
        defer { lock.unlock() }

        pruneLocked(now: Date())

        do {
            switch request {
            case .status:
                return .status(statusLocked())
            case .listTasks:
                return .tasks(tasks)
            case .createTask(let request):
                let task = try makeTask(from: request)
                tasks.append(task)
                persistLocked()
                refreshAssertionsLocked()
                return .task(task)
            case .cancel(let request):
                let result = cancelLocked(request)
                persistLocked()
                refreshAssertionsLocked()
                return .cancel(result)
            case .listWindows:
                return .windows(WindowScanner.listWindows())
            }
        } catch {
            refreshAssertionsLocked()
            return .error(error.localizedDescription)
        }
    }

    public func tick() {
        lock.lock()
        defer { lock.unlock() }
        pruneLocked(now: Date())
        persistLocked()
        refreshAssertionsLocked()
    }

    private func makeTask(from request: TaskRequest) throws -> SleepTask {
        let reason = request.reason?.trimmingCharacters(in: .whitespacesAndNewlines)
        let taskReason = reason?.isEmpty == false ? reason! : "SleepDaemon task"

        switch request.kind {
        case .indefinite:
            return SleepTask(kind: .indefinite, reason: taskReason)
        case .timed:
            guard let seconds = request.durationSeconds, seconds > 0 else {
                throw SleepDaemonError.invalidTask("timed tasks require a positive duration")
            }
            return SleepTask(kind: .timed, reason: taskReason, expiresAt: Date().addingTimeInterval(seconds))
        case .pid:
            guard let pid = request.target?.pid, pid > 0 else {
                throw SleepDaemonError.invalidTask("pid tasks require a positive pid")
            }
            guard ProcessMonitor.pidExists(pid) else {
                throw SleepDaemonError.invalidTask("pid \(pid) is not running")
            }
            return SleepTask(kind: .pid, reason: taskReason, target: TaskTarget(pid: pid))
        case .bundle:
            guard let bundleIdentifier = request.target?.bundleIdentifier, !bundleIdentifier.isEmpty else {
                throw SleepDaemonError.invalidTask("bundle tasks require a bundle identifier")
            }
            guard ProcessMonitor.bundleIsRunning(bundleIdentifier) else {
                throw SleepDaemonError.invalidTask("bundle \(bundleIdentifier) is not running")
            }
            return SleepTask(kind: .bundle, reason: taskReason, target: TaskTarget(bundleIdentifier: bundleIdentifier))
        case .window:
            guard let windowID = request.target?.windowID, windowID > 0 else {
                throw SleepDaemonError.invalidTask("window tasks require a window id")
            }
            guard WindowScanner.windowExists(windowID) else {
                throw SleepDaemonError.invalidTask("window \(windowID) is not visible")
            }
            return SleepTask(kind: .window, reason: taskReason, target: TaskTarget(windowID: windowID))
        }
    }

    private func cancelLocked(_ request: CancelRequest) -> CancelResult {
        let before = tasks.count
        if request.all {
            tasks.removeAll()
        } else if let id = request.id {
            tasks.removeAll { $0.id == id }
        }
        return CancelResult(cancelled: before - tasks.count)
    }

    private func statusLocked() -> SleepStatus {
        SleepStatus(
            sleepPrevented: assertionManager.sleepPrevented,
            activeAssertionTypes: assertionManager.activeAssertionTypes,
            activeTaskCount: tasks.count,
            daemonStartedAt: startedAt,
            version: version
        )
    }

    private func pruneLocked(now: Date) {
        tasks.removeAll { task in
            switch task.kind {
            case .indefinite:
                return false
            case .timed:
                return task.expiresAt.map { $0 <= now } ?? true
            case .pid:
                guard let pid = task.target?.pid else {
                    return true
                }
                return !ProcessMonitor.pidExists(pid)
            case .bundle:
                guard let bundleIdentifier = task.target?.bundleIdentifier else {
                    return true
                }
                return !ProcessMonitor.bundleIsRunning(bundleIdentifier)
            case .window:
                guard let windowID = task.target?.windowID else {
                    return true
                }
                return !WindowScanner.windowExists(windowID)
            }
        }
    }

    private func refreshAssertionsLocked() {
        do {
            let reason = tasks.first?.reason ?? "SleepDaemon task"
            try assertionManager.refresh(activeTaskCount: tasks.count, reason: reason)
        } catch {
            fputs("sleepd: \(error.localizedDescription)\n", stderr)
        }
    }

    private func persistLocked() {
        do {
            try store.save(tasks)
        } catch {
            fputs("sleepd: failed to save tasks: \(error.localizedDescription)\n", stderr)
        }
    }
}

public final class SleepDaemonXPCService: NSObject, SleepDaemonXPCProtocol, @unchecked Sendable {
    private let service: SleepDaemonService

    public init(service: SleepDaemonService) {
        self.service = service
    }

    public func request(_ requestData: NSData, withReply reply: @escaping (NSData) -> Void) {
        do {
            let request = try XPCCodec.decodeRequest(requestData)
            reply(XPCCodec.encodeResponse(service.handle(request)))
        } catch {
            reply(XPCCodec.encodeResponse(.error(error.localizedDescription)))
        }
    }
}
