# NavyRec CLT port

NavyRec is based on lihaoyun6/QuickRecorder 1.6.9. LICENSE is unchanged (AGPL-3.0); original author credits remain in the localized credits and copyright metadata.

## Build

Run `./build.sh`, then `open build/NavyRec.app`. Requires macOS 14+, Apple Command Line Tools, Python 3, and network access for the first SwiftPM dependency resolution. No Xcode installation, xcodebuild, actool, or ibtool is required. Dependencies are pinned in Package.swift/Package.resolved.

The script uses `swift build -c release` with the native SwiftPM build engine. Swift 6.4's default swiftbuild engine probes actool even without this target's asset catalog. The macOS 27 CLT SDK references a missing SwiftUIMacros plugin; this machine also ships MacOSX26.5.sdk, which the script selects. Set NAVYREC_SDK to override the SDK. The deployment target remains macOS 14.

`scripts/prepare-dependencies.py` removes only the three Xcode preview declarations from KeyboardShortcuts 2.2.4 and adjusts its localization lookup for an app bundle. This patch is applied after resolution, is idempotent, and leaves upstream runtime shortcut behavior intact. A bare `swift build` does not apply these CLT compatibility steps; use build.sh.

The app embeds SwiftPM resource bundles in Contents/Resources. Bundle.navyResources first checks that signed-app location, then falls back to Bundle.module for command-line execution. This avoids root-level resource symlinks, which codesign rejects as unsealed contents. Localizable.strings remains in the SwiftPM bundle, with defaultLocalization en. Localizations are also copied to the app's resource directory for SwiftUI's implicit localization, InfoPlist.strings and Credits.rtf. Scriptable.sdef is copied there for AppleScript.

The script copies graphic/AppIcon.icns when provided; otherwise it invokes iconutil on the original PNG iconset. This macOS/CLT combination rejects those valid PNG iconsets, so a sips/ImageIO fallback writes an ICNS from the 1024px original. The QMA icon has the same fallback. The final app is ad-hoc signed with the original microphone/camera entitlements; bundle ID is io.github.navyrec, LSUIElement remains true, and screen/microphone/camera descriptions are included.

## Removed and replaced

- Removed Sparkle imports, updater initialization, updater settings/menu controls, support source, feed/key metadata, package references and appcast.xml. There is no automatic update mechanism.
- Excluded Assets.xcassets from compilation. Raster images (including dynamically named holiday particles) are copied to Resources with scale variants. Generated named colors are code-defined adaptive colors preserving the original light/dark values and color spaces. The window-selection SVG uses the corresponding SF Symbol.
- Rebranded UI/localization strings, notification identifiers, AppleScript class module names and filename prefixes. Filename timestamps include milliseconds and a UUID suffix to prevent collisions during rapid restarts.
- Retained AppleScript commands and the QMA type identifier for file compatibility. The old Xcode project is retained as historical metadata; SwiftPM/build.sh is the supported build path.

## Recording fixes

- Replaced the status button's embedded SwiftUI hosting view with native NSStatusBarButton target/action. Left-click stops recording directly, without opening a popover. Right-click opens a native menu with stop, pause/resume, recording controls, source panel and quit actions. The original floating controls remain available through Recording Controller and as a fallback when the status item is hidden.
- The global stop shortcut defaults to Command-Shift-2. Existing user shortcut choices remain respected. It stops both ScreenCaptureKit and iDevice recordings.
- Stop is idempotent and asynchronous. A sample lock fences append callbacks, further samples are rejected, capture is stopped, inputs are finished, and the captured writer is awaited. No semaphore blocks the main thread. The start guard covers selectors, countdown entry, hotkeys and AppleScript; picker controls disable during finalization.
- Finalization remains busy through optional audio mixing/MP3 conversion. All saved notifications and previews for recording completion require a nonempty file with a finite positive AVAsset duration. MOV/MP4 duration loading checks that finalized movie metadata is readable; QMA validates both contained tracks. Errors retain the source recording when possible and produce a failure notification.
- iDevice recording holds the guard until its didFinishRecording callback and validation complete. Quit waits for finalization rather than terminating while the writer is active. A stop received during asynchronous startup is deferred until startup returns.

## Record UI map

All paths below are relative to QuickRecorder/.

| File / view | Purpose |
| --- | --- |
| QuickRecorderApp.swift / AppDelegate | Creates the main source panel, registers hotkeys, owns the status item and floating windows, and handles application lifecycle. |
| ViewModel/ContentViewNew.swift / ContentViewNew | Current source picker panel with display, window, app, area and audio recording choices. |
| ViewModel/ContentView.swift / ContentView, SelectorView | Older source panel and reusable source-choice buttons; also contains panel/window construction. |
| ViewModel/ScreenSelector.swift / ScreenSelector | Display thumbnails, display selection and start/countdown controls. |
| ViewModel/WinSelector.swift / WinSelector | Window thumbnails, selection and start/countdown controls. |
| ViewModel/AppSelector.swift / AppSelector | Application selection and recording options/start controls. |
| ViewModel/AreaSelector.swift / AreaSelector, resizeView, ScreenshotOverlayView | Draggable/resizable capture rectangle and area control panel. |
| Supports/WindowHighlighter.swift / HighlightMask, CoverView | Highlights a candidate window and provides quick selection/start controls. |
| ViewModel/iDeviceSelector.swift / iDeviceSelector | Mobile-device source, capture preset and start controls. |
| ViewModel/ContentView.swift / CountdownView, createCountdownPanel | Countdown display, cancel button and delayed start action. |
| ViewModel/StatusBar.swift / StatusBarItem | Existing floating stop/pause/time/camera controls; native status-item event handling and menu are in the same file. |
| ViewModel/CameraOverlayer.swift / CameraPopoverView | Camera selection/popover and camera/device overlay controls. |
| ViewModel/MousePointer.swift and ScreenMagnifier.swift | Recording pointer visualization and magnifier overlays. |
| ViewModel/PreviewView.swift | Post-recording preview with playback/save/close actions. |
| Supports/RecordingLifecycle.swift / RecordingStartGate | Shared finalization UI state and disabling of source pickers while saving. |

## Verification and known gaps

- `swift package clean` followed by `./build.sh` succeeded with the resolved dependency checkouts retained. A subsequent incremental build including the final fixes also succeeded. `codesign --verify --deep --strict` passed. LICENSE has no diff; Swift source parsing, shell syntax and `git diff --check` passed.

- `Tests/run-finalization.sh` exercises the production file validator: rejects an empty file, writes and immediately finalizes two consecutive uncompressed MOV files, and verifies positive durations and moov atoms. It does not simulate TCC-authorized screen capture or status-item mouse events.
- The H.264 test encoder was unavailable in this sandbox. The regression test uses uncompressed audio in a MOV container to isolate writer completion and file validation from encoder availability.
- Screen/microphone/camera permissions are tied to the new bundle ID; grant them to NavyRec. End-to-end screen, microphone/AEC, iDevice, audio remix/MP3, menu-click and hotkey recording require interactive validation. No recording UI redesign was attempted.
- This session's filesystem policy marks .git read-only. Attempts to stage/commit failed creating .git/index.lock; no requested commits could be created.

### Launch-check limitation in this session

The signed arm64 executable exists and `codesign --verify --deep --strict` passes. However, `open build/NavyRec.app` returned LaunchServices -10827 (kLSNoExecutableErr); `pgrep -x NavyRec` could not access sysmond/process enumeration; and osascript reported an invalid hiservices XPC connection. Direct execution aborted without console diagnostics. Consequently launch, persistence for three seconds, and AppleScript quit are **not verified** here; they must be checked from an ordinary logged-in Terminal session. These observations do not establish that the application launches successfully outside this restricted session.

## UI pass

Implemented the B start toolbar and C studio panel from `../design/record-ui.html`, with the A-style collapsed pill.

Files changed (under `QuickRecorder/` unless stated otherwise):

- `Supports/Theme.swift`: shared navy/ice/blue/recording/success/text tokens, dark HUD material, 72% navy tint, 16-point corners, one-pixel hairline and keyboard-focus styling.
- `ViewModel/ContentViewNew.swift`: compact source toolbar, optional connected iDevice source, existing Mic/System settings and camera chooser, FPS/quality/cursor/format/save-folder menu. Record opens the existing source selector or audio countdown. Source choice persists; Escape closes the panel. Microphone availability and disconnected-device normalization are retained and refreshed on device changes.
- `QuickRecorderApp.swift`: borderless toolbar at the pointer screen's bottom center; recording controls now open automatically, using a floating panel.
- `ViewModel/StudioPanel.swift`: 300-point studio, draggable remembered origin with offscreen fallback, monospaced timer, Reduce Motion-aware REC dot, separate level meters and ten-second silence warnings, resolution/FPS/file-size/disk-space metadata, pause/resume/stop, top-center compact pill, and Finder-reveal completion/error toasts.
- `Supports/RecordingLevels.swift`: locked numeric meter snapshots, 10 Hz RMS analysis of existing Float32/Int16/Int32 PCM, including interleaved samples; CMSampleBuffer storage is retained while reading; missing buffers decay to silence. No new capture sessions or audio taps.
- `RecordEngine.swift`: meter hooks in ScreenCaptureKit system audio, default mic, AEC and selected-mic callbacks. Screen/application filters exclude NavyRec as an application and explicitly retain the permitted existing overlays, so newly created controls remain excluded even with Hide NavyRec disabled. The panel also uses `sharingType = .none`. Initial content enumeration includes offscreen windows, with overlay windows materialized first, so fast-start shortcuts can retain hidden pointer/magnifier overlays.
- `ViewModel/StatusBar.swift`: native red-dot/monospaced-timer status button, retaining direct left-click Stop (#295) and the right-click menu. Removed the unreferenced old SwiftUI status controller.
- `Supports/RecordingLifecycle.swift`, `SCContext.swift`, `AVContext.swift`: success toast only after existing validation and final-asset duration loading; failure toast on finalization errors; lifecycle cleanup closes controls. Optional legacy preview is positioned above the toast.
- `ViewModel/ContentView.swift`: removed the now-unreferenced big source grid and source-button view; retained countdown/window helpers and made countdown digits monospaced.
- `Tests/RecordingLevelsTests.swift`, `Tests/run-levels.sh`: known-amplitude RMS, track separation, silent PCM, interleaved stereo, CMSampleBuffer and stale-buffer checks.

Verification:

- `swift package clean` followed by `./build.sh`: passed; final follow-up `./build.sh`: passed. Existing upstream Sendable/deprecation warnings and iconutil fallback diagnostics remain.
- `bash Tests/run-levels.sh`: passed.
- `bash Tests/run-finalization.sh`: passed (empty-file rejection and two consecutive finalized movies with playable duration/moov).
- `codesign --verify --deep --strict build/NavyRec.app` and `git diff --check`: passed.
- Requested launch sequence attempted: `open build/NavyRec.app` returned LaunchServices `-10827`; `pgrep -x NavyRec` returned “sysmond service not found / Cannot get process list”; `osascript -e 'tell application "NavyRec" to quit'` reported an invalid hiservices XPC connection. Successful launch and quit remain unverified in this sandbox.

Not done / interactive validation remaining:

- Visual inspection, keyboard navigation/focus appearance, actual screen/mic/AEC recording, camera overlay, capture exclusion, multi-display dragging, status click/hotkey behavior and live toast interactions require a logged-in graphical session with capture permissions. No successful GUI run is claimed.
- The existing iDevice movie-output path exposes no separate mic/system PCM buffers and does not support pause; studio meters show Off and Pause is disabled for that source. No new iDevice audio capture was added.
- The existing audio-only flow always captures system audio. Its toolbar System control shows On and is disabled in that mode; Mic remains optional. Other source modes retain the existing system-audio preference.
- Changes remain in the working tree; no `.git` writes or commits were attempted.

## Selector restyle

Restyled the source option panels to the navy toolbar system, keeping capture actions, selection bindings, option values, and permission checks intact.

Files changed:

- `QuickRecorder/Supports/Theme.swift`: optional NavyButton foreground/border colors, focused thumbnail surface, pixel hairline divider, and shared borderless menu-picker presentation. Existing style defaults remain compatible with the toolbar.
- `QuickRecorder/ViewModel/AreaSelector.swift`: navy area controls and resize sheet, compact Window Area/Resize/Back buttons, top-left Close, Record and timer, and a separate full-size options row.
- `QuickRecorder/ViewModel/ScreenSelector.swift`: navy panel, ice selection borders and blue selection fills, 12-point thumbnail names, shared options row and compact actions.
- `QuickRecorder/ViewModel/WinSelector.swift`: matching window grid, actions, and dark filter/timer popovers.
- `QuickRecorder/ViewModel/AppSelector.swift`: matching app grid and actions; shared OptionsView now uses 13-point muted labels, readable values, borderless menu pickers, blue native checkboxes, and named accessibility labels for microphone controls.
- `QuickRecorder/ViewModel/iDeviceSelector.swift`: dark device panel, explicit Record device actions, consistent Mute checkbox and Preset menu.
- `QuickRecorder/Supports/WindowHighlighter.swift`: dark quick sheet, small top-left Cancel, Record/timer actions, and shared options.
- `QuickRecorder/ViewModel/ContentView.swift`: navy countdown and Cancel, dark selector window chrome, and area host height adjusted for the two-row layout; removed hosting-view focus-ring suppression.

Selectors have an opaque navy base under NavyPanel so contrast is independent of desktop content. Calculated sRGB contrast: text/panel 14.55:1, muted labels and action borders/panel 6.65:1, dark Record text/blue 5.25:1, ice selection border/panel 9.81:1. Decorative dividers and unselected thumbnail outlines retain the specified low-opacity Theme.hairline. Native checkboxes and menu pickers retain native keyboard behavior; custom buttons retain the existing ice focus outline.

Validation: `./build.sh` and `git diff --check`. No app launch attempted for this task; rendered layout and interactive keyboard navigation still require GUI inspection. Changes are left in the working tree.
