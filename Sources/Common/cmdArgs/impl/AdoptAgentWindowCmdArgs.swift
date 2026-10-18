public struct AdoptAgentWindowCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .adoptAgentWindow,
        help: adopt_agent_window_help_generated,
        flags: [
            "--window-id": singleValueSubArgParser(\._windowId, "<window-id>", parseUInt32),
        ],
        posArgs: [],
    )

    public var _windowId: UInt32? = nil
    public var windowId: UInt32 { _windowId.orDie() }
}

func parseAdoptAgentWindowCmdArgs(_ args: StrArrSlice) -> ParsedCmd<AdoptAgentWindowCmdArgs> {
    parseSpecificCmdArgs(AdoptAgentWindowCmdArgs(rawArgs: args), args)
        .filter("--window-id flag is mandatory") { $0._windowId != nil }
}
