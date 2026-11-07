import SwiftUI
import AVFoundation

struct RecordingDot: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var paused = false
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.1, paused: reduceMotion || paused)) { context in
            Circle().fill(Theme.rec).frame(width: 8, height: 8)
                .opacity(paused ? 0.4 : reduceMotion ? 1 : 0.65 + 0.35 * sin(context.date.timeIntervalSinceReferenceDate * .pi * 1.25))
        }.accessibilityHidden(true)
    }
}

struct StudioPanel: View {
    var collapsed: Bool
    @ObservedObject private var pause = PopoverState.shared
    @State private var time = "00:00"
    @State private var mic = -120.0
    @State private var system = -120.0
    @State private var micSilent: Date?
    @State private var systemSilent: Date?
    @State private var now = Date()
    @State private var size = "0 B"
    @State private var free = "—"
    @State private var meta = "Preparing…"
    @State private var markerCount = 0
    private var micEnabled: Bool { StudioController.shared.micEnabled && SCContext.streamType != .idevice }
    private var systemEnabled: Bool { StudioController.shared.systemEnabled && SCContext.streamType != .idevice }

    var body: some View {
        Group {
            if collapsed {
                // Compact bottom-right bar: stays out of the way while working.
                HStack(spacing: 8) {
                    RecordingDot(paused: pause.isPaused)
                    Text(time).font(.system(size: 12, weight: .semibold, design: .monospaced)).monospacedDigit()
                    miniMeter("Mic", db: mic, enabled: micEnabled, since: micSilent)
                    miniMeter("System", db: system, enabled: systemEnabled, since: systemSilent)
                    marker
                    Button { SCContext.stopAnyRecording() } label: { Image(systemName: "stop.fill").font(.system(size: 10)) }
                        .buttonStyle(NavyButton(fill: Theme.recFill, height: 24)).help("Stop recording (⌘⇧2)")
                        .accessibilityLabel("Stop recording")
                    Button { StudioController.shared.show(collapsed: false) } label: { Image(systemName: "chevron.up").font(.system(size: 10, weight: .semibold)) }
                        .buttonStyle(.borderless).foregroundStyle(Theme.mute).help("Expand recording controls")
                        .accessibilityLabel("Expand recording controls")
                }.padding(.leading, 10).padding(.trailing, 8).frame(height: 32)
            } else {
                VStack(spacing: 12) {
                    HStack {
                        Text(time).font(.system(size: 30, weight: .semibold, design: .monospaced)).monospacedDigit()
                        Spacer(minLength: 4)
                        HStack(spacing: 6) { RecordingDot(paused: pause.isPaused); Text(pause.isPaused ? "PAUSED" : "REC").font(.system(size: 10, weight: .semibold)) }
                            .padding(6).background(Theme.rec.opacity(0.14)).clipShape(Capsule())
                        Button { StudioController.shared.show(collapsed: true) } label: { Image(systemName: "chevron.down") }
                            .buttonStyle(.borderless).help("Collapse recording controls")
                    }
                    meter("Mic", db: mic, enabled: micEnabled, since: micSilent)
                    meter("System", db: system, enabled: systemEnabled, since: systemSilent)
                    Rectangle().fill(Theme.hairline).frame(height: 1)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(meta).lineLimit(1).help(meta)
                        HStack { Text(size); Spacer(); Text("\(free) free") }
                    }.font(.system(size: 11)).foregroundStyle(Theme.mute).frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 8) {
                        marker
                        Button { SCContext.pauseRecording() } label: {
                            Label(pause.isPaused ? "Resume" : "Pause", systemImage: pause.isPaused ? "play.fill" : "pause.fill").frame(maxWidth: .infinity)
                        }.buttonStyle(NavyButton(fill: Theme.ice.opacity(0.08))).disabled(SCContext.streamType == .idevice)
                        stop
                    }
                }.padding(14).frame(width: 300)
            }
        }.modifier(NavyPanel()).onAppear(perform: refresh).onReceive(updateTimer) { _ in refresh() }
    }
    private var marker: some View {
        Button { SCContext.addMarker(); markerCount = SCContext.markers.count } label: {
            HStack(spacing: 3) {
                Image(systemName: markerCount > 0 ? "flag.fill" : "flag").font(.system(size: 10))
                if markerCount > 0 { Text("\(markerCount)").font(.system(size: 10, weight: .semibold)).monospacedDigit() }
            }
        }.buttonStyle(NavyButton(fill: Theme.ice.opacity(0.08), height: collapsed ? 24 : 36))
            .help("Mark this moment (⌘⇧M) — saved in info.json and used by the summary")
            .accessibilityLabel("Add marker")
    }
    private var stop: some View {
        Button { SCContext.stopAnyRecording() } label: {
            HStack(spacing: 6) { Image(systemName: "stop.fill"); Text("Stop"); Text("⌘⇧2").font(.system(size: 10, design: .monospaced)) }
        }.buttonStyle(NavyButton(fill: Theme.recFill)).help("Stop recording (⌘⇧2)")
    }
    private func miniMeter(_ title: String, db: Double, enabled: Bool, since: Date?) -> some View {
        let silent = enabled && !pause.isPaused && since.map { now.timeIntervalSince($0) >= 10 } == true
        let level = enabled ? max(0.08, min(1, (db + 60) / 60)) : 0
        return ZStack(alignment: .bottom) {
            Capsule().fill(Theme.ice.opacity(0.12))
            Capsule().fill(silent ? Theme.amber : Theme.ok).frame(height: 16 * level)
        }.frame(width: 4, height: 16)
            .accessibilityLabel("\(title): \(!enabled ? "off" : silent ? "silent" : "\(Int(db)) dBFS")")
            .help(silent ? "\(title) silent for 10 s" : title)
    }
    private func meter(_ title: String, db: Double, enabled: Bool, since: Date?) -> some View {
        let silent = enabled && !pause.isPaused && since.map { now.timeIntervalSince($0) >= 10 } == true
        return HStack(spacing: 8) {
            Text(title).frame(width: 44, alignment: .leading)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.ice.opacity(0.1))
                    Capsule().fill(LinearGradient(colors: [Theme.ok, Theme.amber], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geometry.size.width * (enabled ? max(0, min(1, (db + 60) / 60)) : 0))
                }
            }.frame(height: 6)
            Text(!enabled ? "Off" : silent ? "silent" : db <= -120 ? "−∞" : String(format: "%.0f", db))
                .foregroundStyle(silent ? Theme.amber : Theme.mute).monospacedDigit().frame(width: 38, alignment: .trailing)
        }.font(.system(size: 12)).foregroundStyle(Theme.mute)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(title): \(!enabled ? "off" : silent ? "silent for ten seconds" : "\(Int(db)) dBFS")")
            .help("\(title) level in dBFS")
    }
    private func refresh() {
        now = Date(); time = SCContext.getRecordingLength()
        micSilent = StudioController.shared.micSilent
        systemSilent = StudioController.shared.systemSilent
        mic = pause.isPaused ? -120 : RecordingLevels.shared.read(.mic)
        system = pause.isPaused ? -120 : RecordingLevels.shared.read(.system)
        if !micEnabled || pause.isPaused || mic >= -60 { micSilent = nil } else if micSilent == nil { micSilent = now }
        if !systemEnabled || pause.isPaused || system >= -60 { systemSilent = nil } else if systemSilent == nil { systemSilent = now }
        StudioController.shared.micSilent = micSilent
        markerCount = SCContext.markers.count
        // The amber meter is easy to miss in the compact bar: notify once per silent stretch.
        if let since = micSilent, now.timeIntervalSince(since) >= 30 {
            if !StudioController.shared.micNotified {
                StudioController.shared.micNotified = true
                let name = ud.string(forKey: "micDevice").flatMap { $0 == "default" ? nil : $0 } ?? "your microphone"
                SCContext.showNotification(title: "Microphone is silent",
                                           body: "No sound from \(name) for 30 seconds. Check it is on and unmuted.",
                                           id: "navyrec.micSilent.\(UUID().uuidString)")
            }
        } else if micSilent == nil { StudioController.shared.micNotified = false }
        StudioController.shared.systemSilent = systemSilent
        let settings = SCContext.vwInput?.outputSettings
        var width = (settings?[AVVideoWidthKey] as? NSNumber)?.intValue ?? 0
        var height = (settings?[AVVideoHeightKey] as? NSNumber)?.intValue ?? 0
        var fps = ud.integer(forKey: "frameRate")
        if SCContext.streamType == .idevice,
           let device = (SCContext.captureSession?.inputs.first as? AVCaptureDeviceInput)?.device {
            let dimensions = CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
            width = Int(dimensions.width); height = Int(dimensions.height)
            let interval = device.activeVideoMinFrameDuration.seconds
            if interval.isFinite && interval > 0 { fps = Int((1 / interval).rounded()) }
        }
        let source: String
        switch SCContext.streamType {
        case .screen: source = "Screen"
        case .screenarea: source = "Area"
        case .window, .windows: source = "Window"
        case .application: source = "App"
        case .systemaudio: source = "Audio only"
        case .idevice: source = "iDevice"
        default: source = "Recording"
        }
        meta = source + (width > 0 ? " · \(width) × \(height) · \(fps) fps" : "")
        if let path = SCContext.filePath {
            let url = URL(fileURLWithPath: path)
            var bytes: Int64 = 0
            if url.pathExtension == "qma", let children = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.fileSizeKey]) {
                bytes = children.reduce(0) { $0 + Int64((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
            } else { bytes = ((try? FileManager.default.attributesOfItem(atPath: path)[.size]) as? NSNumber)?.int64Value ?? 0 }
            size = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
            if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: url.deletingLastPathComponent().path), let bytes = attrs[.systemFreeSize] as? NSNumber {
                free = ByteCountFormatter.string(fromByteCount: bytes.int64Value, countStyle: .file)
            }
        }
    }
}

final class StudioController: NSObject, NSWindowDelegate {
    static let shared = StudioController()
    var micEnabled = false
    var systemEnabled = false
    var micSilent: Date?
    var systemSilent: Date?
    var micNotified = false
    func resetSilence() { micSilent = nil; systemSilent = nil; micNotified = false }
    private var collapsed = false
    private var positioning = false
    func show(collapsed: Bool? = nil) {
        // Default to the compact bar; remember if the user expanded it.
        let collapsed = collapsed ?? !ud.bool(forKey: "studioExpanded")
        ud.set(!collapsed, forKey: "studioExpanded")
        guard let screen = (controlPanel.isVisible ? controlPanel.screen : SCContext.screen?.nsScreen) ?? SCContext.getScreenWithMouse() ?? NSScreen.main else { return }
        positioning = true
        self.collapsed = collapsed
        let content = NSHostingView(rootView: StudioPanel(collapsed: collapsed))
        let size = collapsed ? content.fittingSize : NSSize(width: 300, height: 236)
        controlPanel.contentView = content
        controlPanel.appearance = NSAppearance(named: .darkAqua)
        controlPanel.isOpaque = false; controlPanel.sharingType = .none
        controlPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        controlPanel.delegate = self
        let bounds = screen.visibleFrame
        var origin = NSPoint(x: bounds.maxX - size.width - 12, y: bounds.minY + 12)
        // Camera overlay also defaults to bottom-right: sit just above it.
        if camWindow.isVisible, camWindow.screen == screen, camWindow.frame.minX < origin.x + size.width {
            origin.y = camWindow.frame.maxY + 8
        }
        if !collapsed, let saved = ud.string(forKey: "studioOrigin") {
            let point = NSPointFromString(saved)
            if NSScreen.screens.contains(where: { $0.visibleFrame.contains(NSRect(origin: point, size: size)) }) { origin = point }
        }
        controlPanel.setFrame(NSRect(origin: origin, size: size), display: true)
        controlPanel.orderFront(nil)
        positioning = false
    }
    func windowDidMove(_ notification: Notification) {
        if !collapsed && !positioning { ud.set(NSStringFromPoint(controlPanel.frame.origin), forKey: "studioOrigin") }
    }
}

final class RecordingToast {
    static let shared = RecordingToast()
    private var panel: NSPanel?
    private var dismiss: DispatchWorkItem?
    func show(_ message: String, url: URL?, failed: Bool = false) {
        dismiss?.cancel(); panel?.close()
        guard let screen = SCContext.getScreenWithMouse() ?? NSScreen.main else { return }
        let panel = AppDelegate.EscPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        let view = NSHostingView(rootView: Button {
            if let url = url { NSWorkspace.shared.activateFileViewerSelecting([url]) }
        } label: {
            HStack(spacing: 10) {
                Circle().fill(failed ? Theme.rec : Theme.ok).frame(width: 8, height: 8)
                Text(message).font(.system(size: 13)).lineLimit(3).multilineTextAlignment(.leading)
            }.padding(14).frame(width: 420, alignment: .leading)
        }.buttonStyle(.plain).modifier(NavyPanel()))
        panel.contentView = view; panel.isReleasedWhenClosed = false
        panel.level = .floating; panel.backgroundColor = .clear; panel.isOpaque = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.appearance = NSAppearance(named: .darkAqua); panel.sharingType = .none
        let size = view.fittingSize
        panel.setFrame(NSRect(x: screen.visibleFrame.maxX - size.width - 18, y: screen.visibleFrame.minY + 18, width: size.width, height: size.height), display: true)
        panel.orderFront(nil); self.panel = panel
        let work = DispatchWorkItem { [weak panel] in panel?.close() }
        dismiss = work; DispatchQueue.main.asyncAfter(deadline: .now() + 12, execute: work)
    }
}
