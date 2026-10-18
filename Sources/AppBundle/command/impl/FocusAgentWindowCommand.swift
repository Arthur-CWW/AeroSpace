import Common

struct FocusAgentWindowCommand: Command {
    let args: FocusAgentWindowCmdArgs
    let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> BinaryExitCode {
        let windows = AgentWindowPolicy.windows
        guard !windows.isEmpty else { return .fail(io.err("No agent windows are tracked")) }
        let lastId = AgentWindowPolicy.lastFocusedWindowId
        let lastIndex = windows.firstIndex { $0.windowId == lastId }
        let target: Window
        if args.next, let index = windows.firstIndex(where: { $0.windowId == focus.windowOrNil?.windowId }) ?? lastIndex {
            target = windows[(index + 1) % windows.count]
        } else {
            target = lastIndex.map { windows[$0] } ?? windows[0]
        }
        guard target.focusWindow() else { return .fail(io.err("Agent window is not focusable (it may be minimized or hidden)")) }
        AgentWindowPolicy.lastFocusedWindowId = target.windowId
        return .succ
    }
}
