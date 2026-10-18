import Common
import XCTest

final class AppMetadataTest: XCTestCase {
    func testStockStableAndDebugCanManageTheirLoginItems() {
        assertTrue(managesAeroSpaceLoginItems(bundleId: "bobko.aerospace"))
        assertTrue(managesAeroSpaceLoginItems(bundleId: "bobko.aerospace.debug"))
    }

    func testForkCannotManageStockStartupArtifacts() {
        assertFalse(managesAeroSpaceLoginItems(bundleId: "org.arthur.aerospace.fork"))
    }

    func testUnknownAndRenamedAppsCannotManageStockStartupArtifacts() {
        for bundleId in ["com.example.app", "bobko.aerospace.fork", "bobko.aerospace.debug.fork"] {
            assertEquals(managesAeroSpaceLoginItems(bundleId: bundleId), false, additionalMsg: bundleId)
        }
    }

    func testMissingIdentityCannotManageStockStartupArtifacts() {
        assertFalse(managesAeroSpaceLoginItems(bundleId: nil))
        assertFalse(managesAeroSpaceLoginItems(bundleId: ""))
    }

    func testBundledIdentityWinsOverBuildFlagsSoRenamedAppsDoNotUseStockSockets() {
        for bundleId in ["org.arthur.aerospace.fork", "com.example.renamed-aerospace", "bobko.aerospace", "bobko.aerospace.debug"] {
            for isFork in [false, true] {
                for isDebug in [false, true] {
                    assertEquals(
                        resolveAeroSpaceAppId(bundleId: bundleId, isFork: isFork, isDebug: isDebug),
                        bundleId,
                        additionalMsg: "\(bundleId), isFork: \(isFork), isDebug: \(isDebug)",
                    )
                }
            }
        }
    }

    func testMissingBundledIdentityUsesStockBuildIdentityForCliSockets() {
        for bundleId in [nil, ""] as [String?] {
            assertEquals(
                resolveAeroSpaceAppId(bundleId: bundleId, isFork: false, isDebug: false),
                "bobko.aerospace",
            )
            assertEquals(
                resolveAeroSpaceAppId(bundleId: bundleId, isFork: false, isDebug: true),
                "bobko.aerospace.debug",
            )
        }
    }

    func testForkFallbackWinsOverDebugSoForkCliNeverUsesStockDebugSocket() {
        for bundleId in [nil, ""] as [String?] {
            for isDebug in [false, true] {
                assertEquals(
                    resolveAeroSpaceAppId(bundleId: bundleId, isFork: true, isDebug: isDebug),
                    "org.arthur.aerospace.fork",
                )
            }
        }
    }
}
