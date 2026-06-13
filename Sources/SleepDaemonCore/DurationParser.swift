import Foundation

public enum DurationParser {
    public enum Error: Swift.Error, LocalizedError, Equatable {
        case empty
        case invalid(String)

        public var errorDescription: String? {
            switch self {
            case .empty:
                return "duration is empty"
            case .invalid(let value):
                return "invalid duration '\(value)'"
            }
        }
    }

    public static func parse(_ value: String) throws -> TimeInterval {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else {
            throw Error.empty
        }

        let pattern = #"^([0-9]+(?:\.[0-9]+)?)(s|sec|secs|second|seconds|m|min|mins|minute|minutes|h|hr|hrs|hour|hours)?$"#
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        guard let match = regex.firstMatch(in: trimmed, range: range),
              let numberRange = Range(match.range(at: 1), in: trimmed),
              let amount = Double(trimmed[numberRange]),
              amount > 0 else {
            throw Error.invalid(value)
        }

        let unit = Range(match.range(at: 2), in: trimmed).map { String(trimmed[$0]) } ?? "s"
        switch unit {
        case "s", "sec", "secs", "second", "seconds":
            return amount
        case "m", "min", "mins", "minute", "minutes":
            return amount * 60
        case "h", "hr", "hrs", "hour", "hours":
            return amount * 3600
        default:
            throw Error.invalid(value)
        }
    }
}
