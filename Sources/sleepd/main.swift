import Foundation
import SleepDaemonCore

final class ListenerDelegate: NSObject, NSXPCListenerDelegate, @unchecked Sendable {
    private let exportedObject: SleepDaemonXPCService

    init(exportedObject: SleepDaemonXPCService) {
        self.exportedObject = exportedObject
    }

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        connection.exportedInterface = NSXPCInterface(with: SleepDaemonXPCProtocol.self)
        connection.exportedObject = exportedObject
        connection.resume()
        return true
    }
}

@main
struct SleepDaemonMain {
    static func main() {
        let service = SleepDaemonService()
        let xpcService = SleepDaemonXPCService(service: service)
        let delegate = ListenerDelegate(exportedObject: xpcService)
        let listener = NSXPCListener(machServiceName: sleepDaemonMachServiceName)
        listener.delegate = delegate

        let timer = Timer(timeInterval: 1, repeats: true) { _ in
            service.tick()
        }
        RunLoop.main.add(timer, forMode: .default)

        listener.resume()
        RunLoop.main.run()
    }
}
