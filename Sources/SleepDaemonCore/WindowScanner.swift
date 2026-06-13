import AppKit
import CoreGraphics
import Foundation

public enum WindowScanner {
    public static func listWindows() -> [WindowInfo] {
        guard let rawList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        return rawList.compactMap { entry in
            guard let number = entry[kCGWindowNumber as String] as? NSNumber,
                  let pid = entry[kCGWindowOwnerPID as String] as? NSNumber else {
                return nil
            }

            let ownerName = entry[kCGWindowOwnerName as String] as? String ?? "unknown"
            let app = NSRunningApplication(processIdentifier: pid.int32Value)
            let title = entry[kCGWindowName as String] as? String

            return WindowInfo(
                windowID: number.uint32Value,
                ownerPID: pid.int32Value,
                ownerName: ownerName,
                bundleIdentifier: app?.bundleIdentifier,
                title: title?.isEmpty == true ? nil : title
            )
        }
        .sorted { lhs, rhs in
            if lhs.ownerName == rhs.ownerName {
                return lhs.windowID < rhs.windowID
            }
            return lhs.ownerName.localizedCaseInsensitiveCompare(rhs.ownerName) == .orderedAscending
        }
    }

    public static func windowExists(_ id: UInt32) -> Bool {
        listWindows().contains { $0.windowID == id }
    }
}
