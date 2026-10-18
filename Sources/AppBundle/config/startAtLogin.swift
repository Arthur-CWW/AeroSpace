import AppKit
import Common
import ServiceManagement

@MainActor
func syncStartAtLogin() {
    // A local fork must not register itself or remove stock login artifacts.
    guard managesAeroSpaceLoginItems(bundleId: Bundle.main.bundleIdentifier) else { return }
    cleanupPlistFromPrevVersions()
    let service = SMAppService.mainApp
    switch true {
        case !config.startAtLogin: _ = try? service.unregister()
        case isDebug: print("'start-at-login = true' has no effect in debug builds")
        default: _ = try? service.register()
    }
}

private func cleanupPlistFromPrevVersions() { // todo Drop after a couple of versions
    let launchAgentsDir = FileManager.default.homeDirectoryForCurrentUser.appending(component: "Library/LaunchAgents/")
    Result { try FileManager.default.createDirectory(at: launchAgentsDir, withIntermediateDirectories: true) }.getOrDie()
    let url: URL = launchAgentsDir.appending(path: "bobko.aerospace.plist")
    try? FileManager.default.removeItem(at: url)
}
