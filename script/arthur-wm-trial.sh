#!/bin/bash
# Explicit, human-approved transitions only. Never called by the build script.
set -euo pipefail
fail() { printf 'arthur-wm-trial: %s\n' "$*" >&2; exit 1; }
usage() {
    cat <<'EOF'
Usage: ARTHUR_WM_TRIAL_APPROVAL=swap script/arthur-wm-trial.sh swap
       ARTHUR_WM_TRIAL_APPROVAL=rollback script/arthur-wm-trial.sh rollback
Set the matching gate only after the human approves that exact live WM change.
Only /Applications/AeroSpace.app (bobko.aerospace) and
~/Applications/AeroSpace-fork.app (org.arthur.aerospace.fork) are eligible.
Both launch with the existing ~/.aerospace.toml, in the background.
EOF
}
[ "$#" -eq 1 ] || { usage >&2; exit 1; }
case "$1" in
    -h|--help) usage; exit 0 ;;
    swap|rollback) action=$1 ;;
    *) usage >&2; exit 1 ;;
esac
[ "${ARTHUR_WM_TRIAL_APPROVAL:-}" = "$action" ] || fail "Human approval required: set ARTHUR_WM_TRIAL_APPROVAL=$action only after approval."
[ "$(uname -s)" = Darwin ] || fail 'This script is macOS-only.'
stock=/Applications/AeroSpace.app
fork="$HOME/Applications/AeroSpace-fork.app"
config="$HOME/.aerospace.toml"
[ -f "$config" ] && [ -r "$config" ] || fail "Missing readable existing config: $config"
check_app() {
    local path=$1 expected=$2
    [ -d "$path" ] && [ ! -L "$path" ] || fail "Not a regular app directory: $path"
    [ "$(cd "$path" && pwd -P)" = "$path" ] || fail "App path resolves elsewhere: $path"
    [ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$path/Contents/Info.plist")" = "$expected" ] || fail "Wrong bundle identity: $path"
    /usr/bin/codesign --verify --strict "$path" || fail "Invalid signature: $path"
}
# Validate both sides before quitting anything.
check_app "$stock" bobko.aerospace
check_app "$fork" org.arthur.aerospace.fork
if [ "$action" = swap ]; then
    source_path=$stock source_id=bobko.aerospace
    target_path=$fork target_id=org.arthur.aerospace.fork
else
    source_path=$fork source_id=org.arthur.aerospace.fork
    target_path=$stock target_id=bobko.aerospace
fi
# Address only running NSRunningApplication objects after checking their exact
# bundle URLs. Unlike tell application / killall / pkill, this never launches a
# missing source or terminates another AeroSpace installation by process name.
/usr/bin/osascript -l JavaScript - "$source_path" "$source_id" "$target_path" "$target_id" <<'JXA'
ObjC.import('AppKit');
function run(argv) {
    const sourcePath = argv[0], sourceId = argv[1];
    const targetPath = argv[2], targetId = argv[3];
    const apps = $.NSWorkspace.sharedWorkspace.runningApplications;
    let source = null;
    for (let i = 0; i < apps.count; i++) {
        const app = apps.objectAtIndex(i);
        const id = ObjC.unwrap(app.bundleIdentifier);
        if (id !== sourceId && id !== targetId) continue;
        const path = ObjC.unwrap(app.bundleURL.path);
        const expected = id === sourceId ? sourcePath : targetPath;
        if (path !== expected) throw new Error('Refusing unexpected running bundle: ' + path);
        if (id === targetId) throw new Error('Target already running; refusing a concurrent WM transition.');
        if (source !== null) throw new Error('Multiple source instances; refusing transition.');
        source = app;
    }
    if (source !== null) {
        if (!source.terminate) throw new Error('Source refused graceful termination.');
        for (let i = 0; i < 100 && !source.isTerminated; i++) delay(0.1);
        if (!source.isTerminated) throw new Error('Source did not quit; target was not launched. No force-kill attempted.');
    }
}
JXA
/usr/bin/open -g -a "$target_path" --args --config-path "$config"
printf 'Requested background launch: %s using %s. Verify Accessibility and WM behavior manually.\n' "$target_path" "$config"
