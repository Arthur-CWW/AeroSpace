# AeroSpace Beta [![Build](https://github.com/nikitabobko/AeroSpace/actions/workflows/build.yml/badge.svg?branch=main)](https://github.com/nikitabobko/AeroSpace/actions/workflows/build.yml)

<img src="./resources/Assets.xcassets/AppIcon.appiconset/icon.png" width="40%" align="right">

AeroSpace is an i3-like tiling window manager for macOS

Videos:
- [YouTube 91 sec Demo](https://www.youtube.com/watch?v=UOl7ErqWbrk)
- [YouTube Guide by Josean Martinez](https://www.youtube.com/watch?v=-FoWClVHG5g)

Docs:
- [AeroSpace Guide](https://nikitabobko.github.io/AeroSpace/guide)
- [AeroSpace Commands](https://nikitabobko.github.io/AeroSpace/commands)
- [AeroSpace Goodies](https://nikitabobko.github.io/AeroSpace/goodies)

## Arthur's local fork

This fork builds a separate **AeroSpace-fork.app**, bundle ID
`org.arthur.aerospace.fork`, without replacing `/Applications/AeroSpace.app`.
Local build/install does **not** launch either WM, edit `~/.aerospace.toml`, reset
Accessibility permissions, or enable login items. Live switching and the
Accessibility-permission trial remain **pending explicit human approval**.
The stock installation is currently 0.20.3-Beta; do not run both WMs together.

Runtime Accessibility resets target `Bundle.main.bundleIdentifier`, with no
fallback to the stock identity. The fork identity
`org.arthur.aerospace.fork` skips **all** `SMAppService` login-item
synchronization, including unregistering and legacy login-plist cleanup,
regardless of `start-at-login` in the shared config. Thus a fork trial does not
register a fork login item or unregister the stock one. Stock-identity login-item
behavior remains unchanged.

The fork server derives its socket identity from its runtime bundle ID. The
local build compiles the CLI with `ARTHUR_FORK`, making
`org.arthur.aerospace.fork` its default identity as well. Thus
`.arthur-build/aerospace` addresses the fork's isolated socket without a
per-invocation environment variable; it does **not** silently query or control
stock AeroSpace. When the fork is not running, connection failure is expected.
Fork debug-mode behavior likewise does not toggle the stock installation.

### Local build and signing (macOS only)

The upstream package requires **Swift >=6.2**, uses Swift **6.2 language mode**,
and pins the compiler to **6.4.0** in `.swift-version`. These are different
requirements. The available Mac has **Xcode 26.6 (17F113)** with bundled
**Swift 6.3.3**; that bundled compiler does not reproduce the upstream pin.
Select full Xcode through `DEVELOPER_DIR` or `xcode-select`; command-line tools
alone are insufficient. The deployment target is macOS 13.

Swiftly 1.1.4 and the pinned Swift 6.4.0 toolchain are installed on the Mac.
For another Mac, initialize and install the pin first:

```bash
brew install swiftly
swiftly init --no-modify-profile --skip-install --assume-yes
swiftly install 6.4.0 --assume-yes
```

From this repository on the Mac, use the installed toolchain's verified bundle
identifier explicitly:

```bash
./script/arthur-build.sh --toolchain org.swift.640202609131a
./script/arthur-build.sh --toolchain org.swift.640202609131a --install
```

The script checks the selected compiler against `.swift-version` and refuses
a mismatch by default. The checked-in Xcode project refers to an upstream
custom toolchain; `--toolchain` overrides it for both Xcode and the Swift CLI.
For a deliberately non-pinned local build using Xcode's bundled Swift instead:

```bash
./script/arthur-build.sh --allow-toolchain-mismatch
# Add --install only when installation is intended.
```

That override still requires Swift >=6.2 and does not guarantee compatibility.
Build/test success with any compiler must be recorded separately; these commands
are not evidence that the compiler or live WM trial has been validated.

By default signing uses the local
`Apple Development: Created via API (AS8R4Z9F4R)` identity. To select another
local identity, pass `--codesign-identity 'Apple Development: …'`; to use ad-hoc
signing, pass `--codesign-identity -`. Ad-hoc signatures may not retain
Accessibility trust across rebuilds. Signing is local, not notarization.

The native-architecture Release app and SwiftPM CLI are staged at
`.arthur-build/AeroSpace-fork.app` and `.arthur-build/aerospace`. Only explicit
`--install` copies the app to `~/Applications/AeroSpace-fork.app`; the CLI stays
in the build directory. The script uses the checked-in Xcode project, Swift
package dependencies and generated sources. It does not run `generate.sh`,
`build-release.sh`, `git checkout`, docs/completion generation, or install their
Ruby/Rust dependencies. It does not produce universal binaries, release archives,
fresh generated help/version metadata, or a Homebrew cask. Preserve `.arthur-build`
between builds for incremental compilation.

### Approved live trial and rollback

**Do not execute these until the human approves the exact requested transition.**
The approval variable is an explicit gate, not permission to approve on behalf
of the human. No live swap, rollback, or Accessibility grant is implied by build
or installation approval.

After approval to quit the stock WM and launch the installed fork:

```bash
ARTHUR_WM_TRIAL_APPROVAL=swap ./script/arthur-wm-trial.sh swap
```

After approval to quit the fork and relaunch stock:

```bash
ARTHUR_WM_TRIAL_APPROVAL=rollback ./script/arthur-wm-trial.sh rollback
```

Both transitions validate the exact app paths, bundle identities and signatures
before quitting anything. They gracefully quit only the matching running bundle,
wait for termination, and request `open -g` background launch of the other app
with `--config-path "$HOME/.aerospace.toml"`. They never force-kill by process name,
change configuration, or grant permissions. Unexpected paths, symlinks, duplicate
instances, an already-running destination, or failed termination cause refusal.
If a launch fails after the source quits, use the approved opposite transition;
an absent source is allowed so recovery does not require a running fork.
Background launch does not prove that Accessibility permission or window
management works. The separate fork identity needs its own manual Accessibility
approval in System Settings, and rollback cannot reconstruct prior window layout.

### Agent-window policy and explicit commands

The fork's default agent policy is:

```toml
[agent]
workspace = 'agent'
layout = 'floating'
exclude-from-cycling = true
```

The agent workspace must be **named**, not numeric. These defaults keep agent
windows floating on the separate `agent` workspace and exclude that workspace
from ordinary workspace cycling. Detection or adoption does not focus the
window or switch to its workspace.

Launch a new agent process and its descendants through the executable wrapper:

```bash
./script/arthur-agent /path/to/application/executable
```

The wrapper sets `AEROSPACE_AGENT=1` and `exec`s the supplied command. Automatic
ownership detection examines the window owner's process environment and living
ancestors. It fails closed when process information is unreadable or ownership
cannot be proved. Opening another window in an already-running shared browser or
editor does not retag that existing process; explicitly adopt just the intended
window instead:

```bash
./.arthur-build/aerospace list-windows --all
./.arthur-build/aerospace adopt-agent-window --window-id 42
```

Replace `42` with the inspected window ID. Adoption requires an explicit ID and
never silently adopts the focused window or every window of its application.
The local CLI connects only to the fork's isolated socket; use these commands
during an approved fork trial. They cannot query the stock WM when the fork is
absent.

**Human-directed focus only:** the following commands intentionally focus an
agent window and can switch workspaces. Agents must not invoke them as an
automatic part of launching or adoption:

```bash
./.arthur-build/aerospace focus-agent-window
./.arthur-build/aerospace focus-agent-window --next
```

The first selects the most recently adopted/focused available agent window
(falling back to the lowest ID); `--next` cycles in ascending window-ID order.
They do not adopt unmarked windows and fail when no agent window is available.

Launch agent GUI applications in the background/nonactivating mode whenever
the application supports it. macOS can activate an application before AeroSpace
observes its new window; suppression cannot eliminate that transient activation.
Native focus restoration is best effort and cannot reconstruct the previous
native application at startup before a user application has been observed.

### Tracked-window diagnostics and reconciliation

```bash
./.arthur-build/aerospace debug-windows --inventory
# Explicit mutation: run only when removal of proven-stale tree nodes is intended.
./.arthur-build/aerospace debug-windows --reconcile
```

`--inventory` produces JSON for **tracked tree windows**, not every system window
and not automatic adoption. It includes workspace/layout/title, owning PID,
CG metadata, AX enumeration/lookup status, stale/helper hints and removal status.
It does not change interactive debug recording state.

`--reconcile` uses the same evidence and normal garbage-collection/focus-repair
path to remove proven-stale tree nodes. It does not close native windows or kill
applications. An owning application's termination, or confirmed absence from
both a complete successful AX enumeration and a successful CG snapshot matched
by window ID **and PID**, establishes staleness. Hidden/minimized/offscreen,
zero-alpha, unusual-layer, missing-title, helper-candidate and permission-error
observations do not by themselves authorize removal. Reconciliation can change
the tree and repair focus; inspect inventory first rather than using it as a
routine visibility cleanup. Output is a live multi-API snapshot and an unstable
debug API, not a reliable automation contract.

See the command docs for [adoption](./docs/aerospace-adopt-agent-window.adoc),
[explicit focus](./docs/aerospace-focus-agent-window.adoc), and
[inventory/reconciliation](./docs/aerospace-debug-windows.adoc). Chrome
title/profile routing and named-workspace policy remain separate configuration
discussions, not side effects of build/install. None of these instructions claims
that tests or the live permission/WM trial have passed.

## Key features

- Tiling window manager based on a [tree paradigm](https://nikitabobko.github.io/AeroSpace/guide#tree)
- [i3](https://i3wm.org/) inspired
- Fast workspaces switching without animations and without the necessity to disable SIP
- AeroSpace employs its [own emulation of virtual workspaces](https://nikitabobko.github.io/AeroSpace/guide#emulation-of-virtual-workspaces) instead of relying on native macOS Spaces due to [their considerable limitations](https://nikitabobko.github.io/AeroSpace/guide#emulation-of-virtual-workspaces)
- Plain text configuration (dotfiles friendly). See: [default-config.toml](https://nikitabobko.github.io/AeroSpace/guide#default-config)
- CLI first (manpages and shell completion included)
- Doesn't require disabling SIP (System Integrity Protection)
- [Proper multi-monitor support](https://nikitabobko.github.io/AeroSpace/guide#multiple-monitors) (i3-like paradigm)

## Installation

Install via [Homebrew](https://brew.sh/) to get autoupdates (Preferred)

```
brew install --cask nikitabobko/tap/aerospace
```

In multi-monitor setup please make sure that monitors [are properly arranged](https://nikitabobko.github.io/AeroSpace/guide#proper-monitor-arrangement).

Other installation options: https://nikitabobko.github.io/AeroSpace/guide#installation

> [!NOTE]
> By using AeroSpace, you acknowledge that it's not [notarized](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution).
>
> Notarization is a "security" feature by Apple.
> You send binaries to Apple, and they either approve them or not.
> In reality, notarization is about building binaries the way Apple likes it.
>
> I don't have anything against notarization as a concept.
> I specifically don't like the way Apple does notarization.
> I don't have time to deal with Apple.
>
> [Homebrew installation script](https://github.com/nikitabobko/homebrew-tap/blob/main/Casks/aerospace.rb) is configured to
> automatically delete `com.apple.quarantine` attribute, that's why the app should work out of the box, without any warnings that
> "Apple cannot check AeroSpace for malicious software"

## Community, discussions, issues

AeroSpace project doesn't accept Issues directly - we ask you to create a [Discussion](https://github.com/nikitabobko/AeroSpace/discussions) first.
Please read [CONTRIBUTING.md](./CONTRIBUTING.md) for more details.

Community discussions happen at GitHub Discussions.
There you can discuss bugs, propose new features, ask your questions, show off your setup, or just chat.

There are 7 channels:
-   [#all](https://github.com/nikitabobko/AeroSpace/discussions).
    [RSS](https://github.com/nikitabobko/AeroSpace/discussions.atom?discussions_q=sort%3Adate_created).
    Feed with all discussions.
-   [#announcements](https://github.com/nikitabobko/AeroSpace/discussions/categories/announcements).
    [RSS](https://github.com/nikitabobko/AeroSpace/discussions/categories/announcements.atom?discussions_q=category%3Aannouncements+sort%3Adate_created).
    Only maintainers can post here.
    Highly moderated traffic.
-   [#announcements-releases](https://github.com/nikitabobko/AeroSpace/discussions/categories/announcements-releases).
    [RSS](https://github.com/nikitabobko/AeroSpace/discussions/categories/announcements-releases.atom?discussions_q=category%3Aannouncements-releases+sort%3Adate_created).
    Announcements about non-patch releases.
    Only maintainers can post here.
-   [#feature-ideas](https://github.com/nikitabobko/AeroSpace/discussions/categories/feature-ideas).
    [RSS](https://github.com/nikitabobko/AeroSpace/discussions/categories/feature-ideas.atom?discussions_q=category%3Afeature-ideas+sort%3Adate_created).
-   [#general](https://github.com/nikitabobko/AeroSpace/discussions/categories/general).
    [RSS](https://github.com/nikitabobko/AeroSpace/discussions/categories/general.atom?discussions_q=sort%3Adate_created+category%3Ageneral).
-   [#potential-bugs](https://github.com/nikitabobko/AeroSpace/discussions/categories/potential-bugs).
    [RSS](https://github.com/nikitabobko/AeroSpace/discussions/categories/potential-bugs.atom?discussions_q=category%3Apotential-bugs+sort%3Adate_created).
    If you think that you have encountered a bug, you can discuss your bugs here.
-   [#questions-and-answers](https://github.com/nikitabobko/AeroSpace/discussions/categories/questions-and-answers).
    [RSS](https://github.com/nikitabobko/AeroSpace/discussions/categories/questions-and-answers.atom?discussions_q=category%3Aquestions-and-answers+sort%3Adate_created).
    Everyone is welcome to ask questions.
    Everyone is encouraged to answer other people's questions.

## Project status

Public Beta. AeroSpace can be used as a daily driver, but expect breaking changes until 1.0 is reached.

What stops us from 1.0 release:
- [x] https://github.com/nikitabobko/AeroSpace/issues/131 Performance. Implement thread-per-application to circumvent macOS blocking AX API.
- [ ] https://github.com/nikitabobko/AeroSpace/issues/1215 _Big refactoring_. Rewrite mutable double-linked core tree data structure to immutable single-linked persistent tree.
  Important for: stability and potential performance
  - [ ] https://github.com/nikitabobko/AeroSpace/issues/1216 The big refactoring will help us to fix stability issue that windows may randomly jump to the focused workspace
  - [ ] https://github.com/nikitabobko/AeroSpace/issues/68 The big refactoring will help us to support macOS native tabs
- [x] https://github.com/nikitabobko/AeroSpace/issues/278 Implement shell-like combinators.
  Ignore a lot of crazy fuss in the issue,
  We are most probably going with the minimal approach to only introduce common shell-combinators: `||`, `&&`, `;` and `eval` command to send multiple commands in one go.
- [ ] https://github.com/nikitabobko/AeroSpace/issues/1012 Investigate a possibility to use `CGEvent.tapCreate` API for global hotkeys
  - [ ] https://github.com/nikitabobko/AeroSpace/issues/28 Maybe it will allow to distinguish left and right modifiers. Maybe not

Big and important issues which will go after 1.0 release:
- [ ] https://github.com/nikitabobko/AeroSpace/issues/2 sticky windows
- [ ] https://github.com/nikitabobko/AeroSpace/issues/260 Dynamic TWM

## Development

A notes on how to setup the project, build it, how to run the tests, etc. can be found here: [dev-docs/development.md](./dev-docs/development.md)

## Project values

**Values**
- AeroSpace is targeted at advanced users and developers
- Keyboard centric
- Breaking changes (configuration files, CLI, behavior) are avoided as much as possible, but it must not let the software stagnate.
  Thus breaking changes can happen, but with careful considerations and helpful message.
  [Semver](https://semver.org/) major version is bumped in case of a breaking change (It's all guaranteed once AeroSpace reaches 1.0 version, until then breaking changes just happen)
- AeroSpace doesn't use GUI, unless necessarily
  - AeroSpace will never provide a GUI for configuration.
    For advanced users, it's easier to edit a configuration file in text editor rather than navigating through checkboxes in GUI.
  - Status menu icon is ok, because visual feedback is needed
- Provide _practical_ features. Fancy appearance features are not _practical_ (e.g. window borders, transparency, animations, etc.)
- "dark magic" (aka "private APIs", "code injections", etc.) must be avoided as much as possible
  - Right now, AeroSpace uses only a single private API to get window ID of accessibility object `_AXUIElementGetWindow`.
    Everything else is [macOS public accessibility API](https://developer.apple.com/documentation/applicationservices/axuielement_h).
  - AeroSpace will never require you to disable SIP (System Integrity Protection).
  - The goal is to make AeroSpace easily maintainable, and resistant to macOS updates.

**Non Values**
- Play nicely with existing macOS features.
  If limitations are imposed then AeroSpace won't play nicely with existing macOS features
  (For example, AeroSpace doesn't acknowledge the existence of macOS Spaces, and it uses [emulation of its own workspaces](https://nikitabobko.github.io/AeroSpace/guide#emulation-of-virtual-workspaces))
- Ricing.
  AeroSpace provides only a very minimal support for ricing - gaps and a few callbacks for integrations with bars.
  The current maintainer doesn't care about ricing.
  Ricing issues are not a priority, and they are mostly ignored.
  The ricing stance can change only with the appearance of more maintainers.

## macOS compatibility

* AeroSpace binary runs on: macOS 13+
* AeroSpace debug build from sources is supported on: macOS 14+
* AeroSpace release build from sources is supported on: macOS 15+ (Requires: Swift 6.4, Xcode 26.6+)

## Sponsorship

AeroSpace is developed and maintained in my free time.
If you find it useful, [consider sponsoring](https://github.com/sponsors/nikitabobko#sponsors).

## People who have write access

In alphabetical order:

- [@mobile-ar](https://github.com/mobile-ar)
- [@nikitabobko](https://github.com/nikitabobko)
- [@rickyz](https://github.com/rickyz)

## Tip of the day

```bash
defaults write -g NSWindowShouldDragOnGesture -bool true
```

Now, you can move windows by holding `ctrl`+`cmd` and dragging any part of the window (not necessarily the window title)

Source: [reddit](https://www.reddit.com/r/MacOS/comments/k6hiwk/keyboard_modifier_to_simplify_click_drag_of/)

## Related projects

In alphabetical order:

- [Amethyst](https://github.com/ianyh/Amethyst) -
  Beginners friendly GUI-configurable tiling window manager with automatic layouts à la xmonad.
- [InstantSpaceSwitcher](https://github.com/jurplel/InstantSpaceSwitcher) -
  Instant space switching by synthesizing trackpad gesture with an artificially high velocity.
- [rift](https://github.com/acsandmann/rift) -
  Virtual workspaces + private APIs.
- [yabai](https://github.com/koekeishiya/yabai) -
  A window manager that provides tight integration with native macOS Spaces and goes all the way to private APIs and code injection.
  yabai is a source of inspiration for a lot of other OSS projects.
