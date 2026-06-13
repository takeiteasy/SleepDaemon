import Foundation
import IOKit

public enum SleepDaemonError: Error, LocalizedError {
    case assertionFailed(String, IOReturn)
    case invalidTask(String)
    case daemonUnavailable
    case unexpectedResponse

    public var errorDescription: String? {
        switch self {
        case .assertionFailed(let type, let code):
            return "failed to create \(type) assertion: \(code)"
        case .invalidTask(let message):
            return message
        case .daemonUnavailable:
            return "SleepDaemon is not running"
        case .unexpectedResponse:
            return "daemon returned an unexpected response"
        }
    }
}
