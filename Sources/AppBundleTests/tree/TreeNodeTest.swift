@testable import AppBundle
import XCTest

@MainActor
final class TreeNodeTest: XCTestCase {
    override func setUp() async throws {
        setUpWorkspacesForTests()
        AgentWindowPolicy.windowIds = []
        AgentWindowPolicy.lastFocusedWindowId = nil
    }

    func testAgentAdoptionFloatsOnlySelectedWindowWithoutChangingWorkspaceFocus() {
        let workspace = Workspace.get(byName: "ordinary")
        assertTrue(workspace.focusWorkspace())
        let selected = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        let unrelated = TestWindow.new(id: 2, parent: workspace.rootTilingContainer)
        config.agent.workspace = "agent-tools"
        defer {
            AgentWindowPolicy.forget(selected.windowId)
            AgentWindowPolicy.forget(unrelated.windowId)
        }

        AgentWindowPolicy.adopt(selected)

        let agentWorkspace = Workspace.get(byName: "agent-tools")
        XCTAssertTrue(selected.parent === agentWorkspace.floatingWindowsContainer)
        XCTAssertTrue(unrelated.parent === workspace.rootTilingContainer)
        XCTAssertTrue(focus.workspace === workspace)
        XCTAssertTrue(AgentWindowPolicy.windowIds.contains(selected.windowId))
        XCTAssertFalse(AgentWindowPolicy.windowIds.contains(unrelated.windowId))

        AgentWindowPolicy.adopt(selected)
        assertEquals(agentWorkspace.floatingWindowsContainer.children.count, 1)
        XCTAssertTrue(unrelated.parent === workspace.rootTilingContainer)
    }

    func testAgentWindowOrderIsStableAndForgettingFocusedWindowRemovesStaleFocus() {
        let workspace = Workspace.get(byName: "ordinary")
        let higher = TestWindow.new(id: 20, parent: workspace.rootTilingContainer)
        let lower = TestWindow.new(id: 10, parent: workspace.rootTilingContainer)
        defer {
            AgentWindowPolicy.forget(higher.windowId)
            AgentWindowPolicy.forget(lower.windowId)
        }
        AgentWindowPolicy.register(higher)
        AgentWindowPolicy.register(lower)
        AgentWindowPolicy.register(higher)
        assertEquals(AgentWindowPolicy.windows.map(\.windowId), [10, 20])

        AgentWindowPolicy.lastFocusedWindowId = lower.windowId
        AgentWindowPolicy.forget(higher.windowId)
        assertEquals(AgentWindowPolicy.windows.map(\.windowId), [10])
        assertEquals(AgentWindowPolicy.lastFocusedWindowId, lower.windowId)

        AgentWindowPolicy.forget(lower.windowId)
        assertEquals(AgentWindowPolicy.windows.map(\.windowId), [])
        assertEquals(AgentWindowPolicy.lastFocusedWindowId, nil)
    }

    func testChildParentCyclicReferenceMemoryLeak() {
        let workspace = Workspace.get(byName: name) // Don't cache root node
        let window = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)

        XCTAssertTrue(window.parent != nil)
        workspace.rootTilingContainer.unbindFromParent()
        XCTAssertTrue(window.parent == nil)
    }

    func testIsEffectivelyEmpty() {
        let workspace = Workspace.get(byName: name)

        XCTAssertTrue(workspace.isEffectivelyEmpty)
        weak let window: TestWindow? = .new(id: 1, parent: workspace.rootTilingContainer)
        XCTAssertNotEqual(window, nil)
        XCTAssertTrue(!workspace.isEffectivelyEmpty)
        window!.unbindFromParent()
        XCTAssertTrue(workspace.isEffectivelyEmpty)

        // Don't save to local variable
        TestWindow.new(id: 2, parent: workspace.rootTilingContainer)
        XCTAssertTrue(!workspace.isEffectivelyEmpty)
    }

    func testNormalizeContainers_dontRemoveRoot() {
        let workspace = Workspace.get(byName: name)
        weak let root = workspace.rootTilingContainer
        func test() {
            XCTAssertNotEqual(root, nil)
            XCTAssertTrue(root!.isEffectivelyEmpty)
            workspace.normalizeContainers()
            XCTAssertNotEqual(root, nil)
        }
        test()

        config.enableNormalizationFlattenContainers = true
        test()
    }

    func testNormalizeContainers_singleWindowChild() {
        config.enableNormalizationFlattenContainers = true
        let workspace = Workspace.get(byName: name)
        workspace.rootTilingContainer.apply {
            TestWindow.new(id: 0, parent: $0)
            TilingContainer.newHTiles(parent: $0, adaptiveWeight: 1).apply {
                TestWindow.new(id: 1, parent: $0)
            }
        }
        workspace.normalizeContainers()
        assertEquals(
            .h_tiles([.window(0), .window(1)]),
            workspace.rootTilingContainer.layoutDescription,
        )
    }

    func testNormalizeContainers_removeEffectivelyEmpty() {
        let workspace = Workspace.get(byName: name)
        workspace.rootTilingContainer.apply {
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                _ = TilingContainer.newHTiles(parent: $0, adaptiveWeight: 1)
            }
        }
        assertEquals(workspace.rootTilingContainer.children.count, 1)
        workspace.normalizeContainers()
        assertEquals(workspace.rootTilingContainer.children.count, 0)
    }

    func testNormalizeContainers_flattenContainers() {
        let workspace = Workspace.get(byName: name) // Don't cache root node
        workspace.rootTilingContainer.apply {
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                TestWindow.new(id: 1, parent: $0, adaptiveWeight: 1)
            }
        }
        workspace.normalizeContainers()
        XCTAssertTrue(workspace.rootTilingContainer.children.singleOrNil() is TilingContainer)

        config.enableNormalizationFlattenContainers = true
        workspace.normalizeContainers()
        XCTAssertTrue(workspace.rootTilingContainer.children.singleOrNil() is TestWindow)
    }
}
