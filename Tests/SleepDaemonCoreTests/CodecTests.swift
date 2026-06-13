import Testing
import SleepDaemonCore

@Test func requestRoundTrip() throws {
    let request = DaemonRequest.createTask(TaskRequest(kind: .pid, reason: "x", target: TaskTarget(pid: 123)))
    let data = try XPCCodec.encodeRequest(request)
    #expect(try XPCCodec.decodeRequest(data) == request)
}

@Test func responseRoundTrip() throws {
    let response = DaemonResponse.cancel(CancelResult(cancelled: 2))
    let data = XPCCodec.encodeResponse(response)
    #expect(try XPCCodec.decodeResponse(data) == response)
}
