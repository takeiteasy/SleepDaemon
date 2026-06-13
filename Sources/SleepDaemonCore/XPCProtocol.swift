import Foundation

@objc(SleepDaemonXPCProtocol)
public protocol SleepDaemonXPCProtocol {
    func request(_ requestData: NSData, withReply reply: @escaping (NSData) -> Void)
}

public enum XPCCodec {
    public static func encodeRequest(_ request: DaemonRequest) throws -> NSData {
        try SleepDaemonCoding.encoder.encode(request) as NSData
    }

    public static func decodeRequest(_ data: NSData) throws -> DaemonRequest {
        try SleepDaemonCoding.decoder.decode(DaemonRequest.self, from: data as Data)
    }

    public static func encodeResponse(_ response: DaemonResponse) -> NSData {
        do {
            return try SleepDaemonCoding.encoder.encode(response) as NSData
        } catch {
            return (try? SleepDaemonCoding.encoder.encode(DaemonResponse.error(error.localizedDescription)) as NSData) ?? NSData()
        }
    }

    public static func decodeResponse(_ data: NSData) throws -> DaemonResponse {
        try SleepDaemonCoding.decoder.decode(DaemonResponse.self, from: data as Data)
    }
}
