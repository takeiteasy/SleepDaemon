import Foundation
import IOKit.pwr_mgt

public final class PowerAssertionManager {
    private var systemAssertion: IOPMAssertionID = 0
    private var displayAssertion: IOPMAssertionID = 0

    public private(set) var sleepPrevented = false

    public init() {}

    deinit {
        release()
    }

    public var activeAssertionTypes: [String] {
        guard sleepPrevented else {
            return []
        }
        return ["systemIdleSleep", "displaySleep"]
    }

    public func refresh(activeTaskCount: Int, reason: String) throws {
        if activeTaskCount > 0 {
            try acquire(reason: reason)
        } else {
            release()
        }
    }

    private func acquire(reason: String) throws {
        guard !sleepPrevented else {
            return
        }

        let reasonString = reason as CFString
        var systemID: IOPMAssertionID = 0
        var displayID: IOPMAssertionID = 0

        let systemResult = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reasonString,
            &systemID
        )
        guard systemResult == kIOReturnSuccess else {
            throw SleepDaemonError.assertionFailed("system idle sleep", systemResult)
        }

        let displayResult = IOPMAssertionCreateWithName(
            kIOPMAssertionTypeNoDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reasonString,
            &displayID
        )
        guard displayResult == kIOReturnSuccess else {
            IOPMAssertionRelease(systemID)
            throw SleepDaemonError.assertionFailed("display sleep", displayResult)
        }

        systemAssertion = systemID
        displayAssertion = displayID
        sleepPrevented = true
    }

    public func release() {
        if systemAssertion != 0 {
            IOPMAssertionRelease(systemAssertion)
            systemAssertion = 0
        }
        if displayAssertion != 0 {
            IOPMAssertionRelease(displayAssertion)
            displayAssertion = 0
        }
        sleepPrevented = false
    }
}
