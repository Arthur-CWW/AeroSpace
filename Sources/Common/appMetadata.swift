import Foundation

public let stableAeroSpaceAppId: String = "bobko.aerospace"
#if DEBUG
    private let isDebugIdentity = true
    public let aeroSpaceAppName: String = "AeroSpace-Debug"
#else
    private let isDebugIdentity = false
    public let aeroSpaceAppName: String = "AeroSpace"
#endif
#if ARTHUR_FORK
    private let isForkIdentity = true
#else
    private let isForkIdentity = false
#endif

// Command-line executables have no app bundle; bundled apps must use their own identity.
public let aeroSpaceAppId: String = resolveAeroSpaceAppId(
    bundleId: Bundle.main.bundleIdentifier,
    isFork: isForkIdentity,
    isDebug: isDebugIdentity,
)

public func resolveAeroSpaceAppId(bundleId: String?, isFork: Bool, isDebug: Bool) -> String {
    if let bundleId, !bundleId.isEmpty { return bundleId }
    if isFork { return "org.arthur.aerospace.fork" }
    return isDebug ? "bobko.aerospace.debug" : stableAeroSpaceAppId
}

public func managesAeroSpaceLoginItems(bundleId: String?) -> Bool {
    bundleId == stableAeroSpaceAppId || bundleId == "bobko.aerospace.debug"
}
