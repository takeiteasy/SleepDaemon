import Foundation

public final class SleepDaemonClient {
    private let connection: NSXPCConnection

    public init() {
        self.connection = NSXPCConnection(machServiceName: sleepDaemonMachServiceName, options: [])
        self.connection.remoteObjectInterface = NSXPCInterface(with: SleepDaemonXPCProtocol.self)
        self.connection.resume()
    }

    deinit {
        connection.invalidate()
    }

    public func send(_ request: DaemonRequest, timeout: TimeInterval = 10) throws -> DaemonResponse {
        let requestData = try XPCCodec.encodeRequest(request)
        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<DaemonResponse, Error>?

        let proxy = connection.remoteObjectProxyWithErrorHandler { error in
            result = .failure(error)
            semaphore.signal()
        } as? SleepDaemonXPCProtocol

        guard let proxy else {
            throw SleepDaemonError.daemonUnavailable
        }

        proxy.request(requestData) { responseData in
            do {
                result = .success(try XPCCodec.decodeResponse(responseData))
            } catch {
                result = .failure(error)
            }
            semaphore.signal()
        }

        guard semaphore.wait(timeout: .now() + timeout) == .success else {
            throw SleepDaemonError.daemonUnavailable
        }

        switch result {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        case .none:
            throw SleepDaemonError.daemonUnavailable
        }
    }
}
