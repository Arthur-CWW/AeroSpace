import AppKit
import Common
import PrivateApi

// Only positive evidence of destruction can authorize tree repair. Visibility, title,
// minimization and helper heuristics are deliberately absent from this policy.
struct WindowInventoryEvidence: Sendable {
    var appGone: Bool
    var cgPresent: Bool?
    var axEnumerationComplete: Bool
    var axPresent: Bool

    var staleReason: String? {
        if appGone { return "owning-app-gone" }
        if cgPresent == false && axEnumerationComplete && !axPresent { return "absent-from-ax-and-cg" }
        return nil
    }
}

func isWindowInventoryHelper(role: String?, subrole: String?, layer: Int?) -> Bool {
    guard let layer, layer != 0, let role else { return false }
    return role != kAXWindowRole || subrole == kAXFloatingWindowSubrole
}

private struct InventoryAxWindow: Sendable {
    var title: String?
    var role: String?
    var subrole: String?
    var minimized: Bool?
}

private struct InventoryAxApp: Sendable {
    var status: String
    var complete: Bool = false
    var windows: [UInt32: InventoryAxWindow] = [:]
}

// Use a separate AX application object off the main thread. Do not consult the
// MacApp window cache: absence from a cache is not evidence of window destruction.
private func inventoryAxApp(pid: pid_t) -> InventoryAxApp {
    guard AXIsProcessTrusted() else { return .init(status: "permission-denied") }
    let app = AXUIElementCreateApplication(pid)
    AXUIElementSetMessagingTimeout(app, 1)
    var raw: CFTypeRef?
    let error = unsafe AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &raw)
    guard error == .success else { return .init(status: "error-\(error.rawValue)") }
    guard let windows = raw as? [AXUIElement] else { return .init(status: "invalid-ax-windows") }
    var result = InventoryAxApp(status: "success", complete: true)
    for window in windows {
        var id: CGWindowID = 0
        guard unsafe _AXUIElementGetWindow(window, &id) == .success, id != kCGNullWindowID else {
            // Even one unmappable element makes absence inconclusive.
            result.complete = false
            result.status = "incomplete-window-ids"
            continue
        }
        result.windows[id] = .init(
            title: window.get(Ax.titleAttr),
            role: window.get(Ax.roleAttr),
            subrole: window.get(Ax.subroleAttr),
            minimized: window.get(Ax.minimizedAttr),
        )
    }
    return result
}

private struct InventoryCgWindow: Encodable {
    var present: Bool?
    var onscreen: Bool?
    var layer: Int?
    var alpha: Double?
    var bounds: [String: Double]?
}

private struct InventoryRow: Encodable {
    var windowId: UInt32
    var pid: pid_t
    var workspace: String?
    var title: String?
    var layout: String
    var cg: InventoryCgWindow
    var axEnumerationStatus: String
    var axLookupStatus: String
    var role: String?
    var subrole: String?
    var minimized: Bool?
    var appHidden: Bool
    var staleCandidate: Bool
    var staleReason: String?
    var helperCandidate: Bool
    var removed: Bool
}

private struct InventoryResult: Encodable {
    var mode: String
    var cgEnumerationStatus: String
    var windows: [InventoryRow]
}

@MainActor
func runWindowInventory(reconcile: Bool, io: CmdIo) async -> BinaryExitCode {
    let windows = MacWindow.allWindows.sorted { $0.windowId < $1.windowId }
    var apps: [pid_t: InventoryAxApp] = [:]
    for window in windows where apps[window.app.pid] == nil {
        let pid = window.app.pid
        if window.macApp.nsApp.isTerminated {
            apps[pid] = .init(status: "owning-app-gone")
        } else {
            apps[pid] = await withCheckedContinuation { continuation in
                Thread {
                    continuation.resume(returning: inventoryAxApp(pid: pid))
                }.start()
            }
        }
    }
    // optionAll is essential: a different Space, minimization, or AeroSpace's
    // offscreen placement must never be mistaken for a closed window.
    let cgList = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]]
    var cgById: [UInt32: [String: Any]] = [:]
    for entry in cgList ?? [] {
        if let id = (entry[kCGWindowNumber as String] as? NSNumber)?.uint32Value {
            cgById[id] = entry
        }
    }
    var rows: [InventoryRow] = []
    for window in windows {
        // Another refresh may have removed this node while AX enumeration awaited.
        guard MacWindow.allWindowsMap[window.windowId] === window else { continue }
        let axApp = apps[window.app.pid] ?? .init(status: "not-enumerated")
        let ax = axApp.windows[window.windowId]
        let entry = cgById[window.windowId]
        let cgOwner = (entry?[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value
        // Never join a reused CG id to a different owning PID. Missing ownership
        // metadata makes existence unknown rather than proving absence.
        let matchingEntry = cgOwner == window.app.pid ? entry : nil
        let cg = InventoryCgWindow(
            present: cgList == nil || (entry != nil && cgOwner == nil) ? nil : matchingEntry != nil,
            onscreen: matchingEntry?[kCGWindowIsOnscreen as String] as? Bool,
            layer: matchingEntry?[kCGWindowLayer as String] as? Int,
            alpha: matchingEntry?[kCGWindowAlpha as String] as? Double,
            bounds: matchingEntry?[kCGWindowBounds as String] as? [String: Double],
        )
        let evidence = WindowInventoryEvidence(
            appGone: window.macApp.nsApp.isTerminated,
            cgPresent: cg.present,
            axEnumerationComplete: axApp.complete,
            axPresent: ax != nil,
        )
        let layout: String = switch window.windowParentCases {
            case .unbound: "unbound"
            case .tilingContainer(let parent): String(describing: parent.layout)
            case .floatingWindowsContainer: "floating"
            case .macosMinimizedWindowsContainer: "macos-minimized"
            case .macosHiddenAppsWindowsContainer: "macos-hidden"
            case .macosFullscreenWindowsContainer: "macos-fullscreen"
            case .macosPopupWindowsContainer: "macos-popup"
        }
        let remove = reconcile && evidence.staleReason != nil
        rows.append(.init(
            windowId: window.windowId,
            pid: window.app.pid,
            workspace: window.nodeWorkspace?.name,
            title: ax?.title ?? (matchingEntry?[kCGWindowName as String] as? String),
            layout: layout,
            cg: cg,
            axEnumerationStatus: axApp.status,
            axLookupStatus: ax != nil ? "found" : (axApp.complete ? "absent" : "unknown"),
            role: ax?.role,
            subrole: ax?.subrole,
            minimized: ax?.minimized,
            appHidden: window.macApp.nsApp.isHidden,
            staleCandidate: evidence.staleReason != nil,
            staleReason: evidence.staleReason,
            helperCandidate: isWindowInventoryHelper(role: ax?.role, subrole: ax?.subrole, layer: cg.layer),
            removed: remove,
        ))
        if remove { window.garbageCollect(skipClosedWindowsCache: false) }
    }
    let result = InventoryResult(
        mode: reconcile ? "reconcile" : "inventory",
        cgEnumerationStatus: cgList == nil ? "unavailable" : "success",
        windows: rows,
    )
    guard let json = JSONEncoder.aeroSpaceDefault.encodeToString(result) else {
        return .fail(io.err("Unable to encode window inventory"))
    }
    return .succ(io.out(json))
}
