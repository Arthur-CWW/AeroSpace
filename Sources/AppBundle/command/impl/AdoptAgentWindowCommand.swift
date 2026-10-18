import AppKit
import Common

struct AdoptAgentWindowCommand: Command {
    let args: AdoptAgentWindowCmdArgs
    let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) async -> BinaryExitCode {
        do {
            let inventory = try await MacApp.refreshAllAndGetAliveWindowIds(frontmostAppBundleId: NSWorkspace.shared.frontmostApplication?.bundleIdentifier)
            guard let app = inventory.first(where: { $0.value.contains(args.windowId) })?.key else {
                return .fail(io.err("Can't find live window with ID \(args.windowId)"))
            }
            if let existing = Window.get(byId: args.windowId), existing.app.pid != app.pid {
                return .fail(io.err("Window ownership changed; refresh the window inventory and retry"))
            }
            let window = try await MacWindow.getOrRegister(windowId: args.windowId, macApp: app, adoptAsAgent: true)
            AgentWindowPolicy.adopt(window)
            return .succ
        } catch {
            return .fail(io.err("Can't adopt agent window: \(error)"))
        }
    }
}
