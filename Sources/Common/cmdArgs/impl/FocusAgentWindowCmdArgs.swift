public struct FocusAgentWindowCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .focusAgentWindow,
        help: focus_agent_window_help_generated,
        flags: [
            "--next": trueBoolFlag(\.next),
        ],
        posArgs: [],
    )

    public var next: Bool = false
}
