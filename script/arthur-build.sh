#!/bin/bash
# Local-only release route: checked-in Xcode app project + SwiftPM CLI.
set -euo pipefail

fail() { printf 'arthur-build: %s\n' "$*" >&2; exit 1; }
usage() {
    cat <<'EOF'
Usage: script/arthur-build.sh [--install] [--codesign-identity ID]
                             [--toolchain ID] [--allow-toolchain-mismatch]
Builds .arthur-build/AeroSpace-fork.app and .arthur-build/aerospace.
--install copies only the app to ~/Applications/AeroSpace-fork.app; never launches.
Default signing: Apple Development: Created via API (AS8R4Z9F4R).
Use --codesign-identity - for ad-hoc signing (Accessibility trust may not persist).
Default toolchain: com.apple.dt.toolchain.XcodeDefault, resolved through xcrun.
The compiler must match .swift-version unless explicitly opting out; Swift >=6.2
is always required. Select Xcode with DEVELOPER_DIR or xcode-select beforehand.
EOF
}

install=0
allow_mismatch=0
identity='Apple Development: Created via API (AS8R4Z9F4R)'
toolchain=com.apple.dt.toolchain.XcodeDefault
while [ "$#" -gt 0 ]; do
    case "$1" in
        --install) install=1; shift ;;
        --allow-toolchain-mismatch) allow_mismatch=1; shift ;;
        --codesign-identity|--toolchain)
            [ "$#" -ge 2 ] && [ -n "$2" ] || fail "Missing value for $1"
            case "$1" in
                --codesign-identity) identity=$2 ;;
                --toolchain) toolchain=$2 ;;
            esac
            shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) fail "Unknown option: $1" ;;
    esac
done
[ "$(uname -s)" = Darwin ] || fail 'Build on macOS with full Xcode, not Linux.'
root=$(cd "$(dirname "$0")/.." && pwd -P)
cd "$root"
build="$root/.arthur-build"
[ ! -L "$build" ] || fail '.arthur-build must not be a symlink.'
export TOOLCHAINS="$toolchain"
/usr/bin/xcodebuild -version
compiler_info=$(/usr/bin/xcrun --toolchain "$toolchain" swift --version)
printf '%s\n' "$compiler_info"
[[ "$compiler_info" =~ Swift\ version\ ([0-9]+)\.([0-9]+)(\.([0-9]+))? ]] || fail 'Cannot determine Swift compiler version.'
major=${BASH_REMATCH[1]}
minor=${BASH_REMATCH[2]}
patch=${BASH_REMATCH[4]:-0}
actual="$major.$minor.$patch"
IFS= read -r pinned < .swift-version
if [ "$actual" != "$pinned" ]; then
    [ "$allow_mismatch" = 1 ] || fail "Upstream pins Swift $pinned; selected compiler is $actual. Select that toolchain, or explicitly pass --allow-toolchain-mismatch for a non-pinned local build."
    printf 'WARNING: non-pinned local compiler %s (upstream: %s). Compatibility is not guaranteed.\n' "$actual" "$pinned" >&2
fi
[ "$major" -gt 6 ] || { [ "$major" -eq 6 ] && [ "$minor" -ge 2 ]; } || fail 'Package.swift requires Swift >=6.2.'
arch=$(uname -m)
case "$arch" in arm64|x86_64) ;; *) fail "Unsupported native architecture: $arch" ;; esac
mkdir -p "$build"

# Keep the same compiler for SwiftPM and Xcode, bypassing the upstream project's
# generated custom TOOLCHAINS ID. No generation, checkout, docs or completions.
swift_build=(--package-path "$root" --scratch-path "$build/swift" -c release --arch "$arch" --product aerospace)
/usr/bin/xcrun --toolchain "$toolchain" swift build "${swift_build[@]}"
cli_bin=$(/usr/bin/xcrun --toolchain "$toolchain" swift build "${swift_build[@]}" --show-bin-path)
/usr/bin/xcodebuild build \
    -project "$root/xcode/AeroSpace.xcodeproj" -scheme AeroSpace \
    -configuration Release -destination 'generic/platform=macOS' \
    -derivedDataPath "$build/xcode" \
    "TOOLCHAINS=$toolchain" SWIFT_VERSION=6.2 \
    "ARCHS=$arch" ONLY_ACTIVE_ARCH=YES \
    PRODUCT_NAME=AeroSpace-fork PRODUCT_BUNDLE_IDENTIFIER=org.arthur.aerospace.fork \
    INFOPLIST_KEY_CFBundleDisplayName=AeroSpace-fork \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO

app="$build/AeroSpace-fork.app"
# Refuse to overwrite unexpected bundles, including symbolic links.
check_fork() {
    [ ! -L "$1" ] && [ -d "$1" ] || fail "Not a regular app directory: $1"
    [ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$1/Contents/Info.plist")" = org.arthur.aerospace.fork ] || fail "Wrong bundle identity: $1"
}
if [ -e "$app" ] || [ -L "$app" ]; then
    check_fork "$app"
    /bin/rm -rf "$app"
fi
/usr/bin/ditto "$build/xcode/Build/Products/Release/AeroSpace-fork.app" "$app"
check_fork "$app"
/bin/cp "$cli_bin/aerospace" "$build/aerospace"
/usr/bin/codesign --force --sign "$identity" --entitlements "$root/resources/AeroSpace.entitlements" "$app"
/usr/bin/codesign --force --sign "$identity" "$build/aerospace"
/usr/bin/codesign --verify --strict "$app"
/usr/bin/codesign --verify --strict "$build/aerospace"
if [ "$install" = 1 ]; then
    destination="$HOME/Applications/AeroSpace-fork.app"
    mkdir -p "$HOME/Applications"
    [ "$(cd "$HOME/Applications" && pwd -P)" = "$HOME/Applications" ] || fail '~/Applications must not resolve elsewhere.'
    if [ -e "$destination" ] || [ -L "$destination" ]; then
        check_fork "$destination"
        # Updating a running WM is not an installation operation.
        if /usr/bin/pgrep -f "$destination/Contents/MacOS/" >/dev/null; then
            fail 'Installed fork is running; quit it explicitly before replacing it.'
        fi
        /bin/rm -rf "$destination"
    fi
    /usr/bin/ditto "$app" "$destination"
    printf 'Installed %s (not launched).\n' "$destination"
fi
printf 'Built %s and %s/aerospace (not launched).\n' "$app" "$build"
