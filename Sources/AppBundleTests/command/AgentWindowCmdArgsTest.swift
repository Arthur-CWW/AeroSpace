@testable import AppBundle
import Common
import XCTest

@MainActor
final class AgentWindowCmdArgsTest: XCTestCase {
    func testAdoptRequiresExplicitWindowIdSoFocusedWindowIsNotImplicitlyAdopted() {
        assertEquals(parseCommand("adopt-agent-window").errorOrNil, "--window-id flag is mandatory")
        testParseSingleCommandSucc(
            "adopt-agent-window --window-id 42",
            AdoptAgentWindowCmdArgs(rawArgs: []).copy(\._windowId, 42),
        )
        testParseSingleCommandSucc(
            "adopt-agent-window --window-id 4294967295",
            AdoptAgentWindowCmdArgs(rawArgs: []).copy(\._windowId, UInt32.max),
        )
    }

    func testAdoptRejectsMissingMalformedAndOverflowingWindowIds() {
        assertEquals(
            parseCommand("adopt-agent-window --window-id").errorOrNil,
            "ERROR: '--window-id' must be followed by '<window-id>'",
        )
        for value in ["not-a-window", "4294967296"] {
            assertEquals(
                parseCommand("adopt-agent-window --window-id \(value)").errorOrNil,
                "ERROR: Failed to parse '\(value)' CLI argument: Can't convert '\(value)' to UInt32",
            )
        }
        XCTAssertNotNil(parseCommand("adopt-agent-window --window-id -1").errorOrNil)
    }

    func testAdoptRejectsAmbiguousIdsAndUnexpectedArguments() {
        assertEquals(
            parseCommand("adopt-agent-window --window-id 42 --window-id 43").errorOrNil,
            "ERROR: Duplicated option '--window-id'",
        )
        assertEquals(parseCommand("adopt-agent-window 42").errorOrNil, "ERROR: Unknown argument '42'")
        assertEquals(
            parseCommand("adopt-agent-window --window-id 42 --next").errorOrNil,
            "ERROR: Unknown flag '--next'",
        )
    }

    func testFocusAcceptsCurrentAgentSelectionOrExplicitNext() {
        testParseSingleCommandSucc("focus-agent-window", FocusAgentWindowCmdArgs(rawArgs: []))
        testParseSingleCommandSucc(
            "focus-agent-window --next",
            FocusAgentWindowCmdArgs(rawArgs: []).copy(\.next, true),
        )
    }

    func testFocusRejectsDuplicateNextAndImplicitAdoptionOptions() {
        assertEquals(
            parseCommand("focus-agent-window --next --next").errorOrNil,
            "ERROR: Duplicated option '--next'",
        )
        assertEquals(
            parseCommand("focus-agent-window --window-id 42").errorOrNil,
            "ERROR: Unknown flag '--window-id'",
        )
        assertEquals(
            parseCommand("focus-agent-window next").errorOrNil,
            "ERROR: Unknown argument 'next'",
        )
    }

    func testAdoptHelpDoesNotRequireAWindowTarget() {
        for flag in ["-h", "--help"] {
            switch parseCmdArgs(["adopt-agent-window", flag].slice) {
                case .help: break
                case .cmd, .failure: XCTFail("Help must be available without adopting a window")
            }
        }
    }
}
