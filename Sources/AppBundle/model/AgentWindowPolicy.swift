import AppKit
import Common

@MainActor enum AgentWindowPolicy {
    // Ownership is per window. Explicit adoption must not capture unrelated
    // windows belonging to an already-running shared app.
    static var windowIds: Set<UInt32> = []
    static var lastFocusedWindowId: UInt32?
    private static var lastUserApp: NSRunningApplication?

    static func register(_ window: Window) {
        windowIds.insert(window.windowId)
        lastFocusedWindowId = window.windowId
    }

    static func forget(_ windowId: UInt32) {
        windowIds.remove(windowId)
        if lastFocusedWindowId == windowId { lastFocusedWindowId = nil }
    }

    static var windows: [Window] {
        windowIds.compactMap { Window.get(byId: $0) }.sorted { $0.windowId < $1.windowId }
    }

    static func adopt(_ window: Window) {
        register(window)
        window.unbindFromParent()
        window.bind(to: Workspace.get(byName: config.agent.workspace).floatingWindowsContainer,
                    adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
    }

    // Do not turn a native activation by a background agent into workspace or
    // focus callbacks (notably move-mouse callbacks). Explicit focus commands
    // update model focus first, so their native activation is allowed through.
    static func suppressNativeFocus(_ window: Window?) -> Bool {
        let frontmost = NSWorkspace.shared.frontmostApplication
        let ownedWindow = window.map { windowIds.contains($0.windowId) } ?? false
        let ownedAppWithoutWindow = window == nil && frontmost.map { isAgentProcess($0.processIdentifier) } == true
        guard ownedWindow || ownedAppWithoutWindow else {
            lastUserApp = frontmost
            return false
        }
        if let window, focus.workspace == window.nodeWorkspace {
            lastFocusedWindowId = window.windowId
            return false
        }
        if window == nil, focus.workspace.name == config.agent.workspace { return false }
        if let userWindow = focus.windowOrNil {
            userWindow.nativeFocus()
        } else if !serverArgs.isReadOnly, let lastUserApp, !lastUserApp.isTerminated,
                  frontmost?.processIdentifier != lastUserApp.processIdentifier {
            lastUserApp.activate(options: .activateIgnoringOtherApps)
        }
        return true
    }
}
