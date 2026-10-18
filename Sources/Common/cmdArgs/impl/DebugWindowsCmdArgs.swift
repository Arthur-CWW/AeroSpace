public struct DebugWindowsCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .debugWindows,
        help: debug_windows_help_generated,
        flags: [
            "--window-id": windowIdSubArgParser(),
            "--inventory": trueBoolFlag(\.inventory),
            "--reconcile": trueBoolFlag(\.reconcile),
        ],
        posArgs: [],
        conflictingOptions: [
            ["--inventory", "--reconcile"],
            ["--inventory", "--window-id"],
            ["--reconcile", "--window-id"],
        ],
    )

    public var inventory: Bool = false
    public var reconcile: Bool = false
}
