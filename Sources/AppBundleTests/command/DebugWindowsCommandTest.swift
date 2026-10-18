@testable import AppBundle
import Common
import XCTest

@MainActor
final class DebugWindowsCommandTest: XCTestCase {
    func testInventoryAndReconcileCannotAccidentallyStartRecordingOrCombineWithWindowDump() {
        testParseSingleCommandSucc(
            "debug-windows --inventory",
            DebugWindowsCmdArgs(rawArgs: [].slice).copy(\.inventory, true),
        )
        testParseSingleCommandSucc(
            "debug-windows --reconcile",
            DebugWindowsCmdArgs(rawArgs: [].slice).copy(\.reconcile, true),
        )
        for (command, message) in [
            ("debug-windows --inventory --reconcile", "ERROR: Conflicting options: --inventory, --reconcile"),
            ("debug-windows --inventory --window-id 1", "ERROR: Conflicting options: --inventory, --window-id"),
            ("debug-windows --reconcile --window-id 1", "ERROR: Conflicting options: --reconcile, --window-id"),
        ] {
            testParseCommandFail(command, msg: message, exitCode: 2)
        }
        assertNil(parseCommand("debug-windows").errorOrNil)
        assertNil(parseCommand("debug-windows --window-id 1").errorOrNil)
    }

    func testLiveOwnerRequiresBothAuthoritativeAbsencesSoAxFailureNeverDropsWindows() {
        // Exhaust the evidence states, including unavailable CG inventory and AX
        // partial/error/permission failure (all represented by incomplete enumeration).
        for cgPresent in [nil, false, true] as [Bool?] {
            for complete in [false, true] {
                for axPresent in [false, true] {
                    let evidence = WindowInventoryEvidence(
                        appGone: false,
                        cgPresent: cgPresent,
                        axEnumerationComplete: complete,
                        axPresent: axPresent,
                    )
                    if cgPresent == false && complete && !axPresent {
                        assertEquals(evidence.staleReason, "absent-from-ax-and-cg")
                    } else {
                        assertNil(evidence.staleReason)
                    }
                }
            }
        }
    }

    func testTerminatedOwnerIsSufficientEvenWhenAccessibilityAndCgAreUnavailable() {
        let evidence = WindowInventoryEvidence(
            appGone: true,
            cgPresent: nil,
            axEnumerationComplete: false,
            axPresent: false,
        )
        assertEquals(evidence.staleReason, "owning-app-gone")
    }

    func testCgPresenceProtectsOffscreenAndMinimizedWindowsEvenIfAxOmitsThem() {
        let evidence = WindowInventoryEvidence(
            appGone: false,
            cgPresent: true,
            axEnumerationComplete: true,
            axPresent: false,
        )
        assertNil(evidence.staleReason)
    }

    func testHelperRequiresCorroboratingLayerAndAxTypeNotJustMissingMetadata() {
        assertEquals(isWindowInventoryHelper(role: nil, subrole: nil, layer: 3), false)
        assertEquals(isWindowInventoryHelper(role: "AXWindow", subrole: "AXStandardWindow", layer: 0), false)
        assertEquals(isWindowInventoryHelper(role: "AXWindow", subrole: "AXDialog", layer: 3), false)
        assertEquals(isWindowInventoryHelper(role: "AXWindow", subrole: "AXFloatingWindow", layer: nil), false)
        assertEquals(isWindowInventoryHelper(role: "AXWindow", subrole: "AXFloatingWindow", layer: 3), true)
        assertEquals(isWindowInventoryHelper(role: "AXMenu", subrole: nil, layer: 3), true)
    }
}
