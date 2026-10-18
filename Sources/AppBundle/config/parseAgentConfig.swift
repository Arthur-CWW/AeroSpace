import Common

struct AgentConfig: ConvenienceMutable {
    var workspace: String = "agent"
    var layout: String = "floating"
    var excludeFromCycling: Bool = true
}

private let agentParserTable: [String: any ParserProtocol<AgentConfig>] = [
    "workspace": Parser(\.workspace, parseAgentWorkspace),
    "layout": Parser(\.layout, parseAgentLayout),
    "exclude-from-cycling": Parser(\.excludeFromCycling, parseBool),
]

func parseAgentConfig(_ raw: OrderedJson, _ backtrace: ConfigBacktrace, _ c: inout ConfigParserContext) -> AgentConfig {
    parseTable(raw, AgentConfig(), agentParserTable, backtrace, &c)
}

private func parseAgentWorkspace(_ raw: OrderedJson, _ backtrace: ConfigBacktrace) -> ResOrConfigParseDiagnostic<String> {
    parseString(raw, backtrace).flatMap { name in
        guard case .success = WorkspaceName.parse(name), !name.allSatisfy(\.isNumber) else {
            return .failure(.init(backtrace, "Agent workspace must be a valid, non-numbered workspace name"))
        }
        return .success(name)
    }
}

private func parseAgentLayout(_ raw: OrderedJson, _ backtrace: ConfigBacktrace) -> ResOrConfigParseDiagnostic<String> {
    parseString(raw, backtrace).flatMap { layout in
        layout == "floating"
            ? .success(layout)
            : .failure(.init(backtrace, "Agent layout must be 'floating'"))
    }
}
