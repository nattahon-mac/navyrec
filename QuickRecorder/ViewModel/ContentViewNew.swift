import SwiftUI
import AVFoundation

/// Source choice is staged here; Record enters the existing picker/countdown flow.
struct ContentViewNew: View {
    @AppStorage("recordSource") private var source = "Screen"
    @State private var devicePopover = false
    @State private var cameraPopover = false
    @State private var cameraOn = SCContext.isCameraRunning()
    @State private var devices = SCContext.getiDevice()
    @State private var microphones = SCContext.getMicrophone()
    @AppStorage("micDevice") private var micDevice = "default"
    @AppStorage("archiveFolders") private var archiveFolders = true
    @AppStorage("autoTranscribe") private var autoTranscribe = true
    @AppStorage("autoSummary") private var autoSummary = true
    @AppStorage("quickMeetingPreset") private var quickMeetingPreset = true
    @AppStorage("recordMic") private var mic = false
    @AppStorage("recordWinSound") private var system = true
    @AppStorage("frameRate") private var fps = 60
    @AppStorage("videoQuality") private var quality = 1.0
    @AppStorage("videoFormat") private var format = "mp4"
    @AppStorage("showMouse") private var cursor = true
    private let sources = [("Screen", "display"), ("Window", "macwindow"), ("App", "macwindow.on.rectangle"), ("Area", "rectangle.dashed"), ("Audio only", "waveform")]

    var body: some View {
        HStack(spacing: 4) {
            HStack(spacing: 2) {
                ForEach(sources, id: \.0) { name, icon in sourceButton(name, icon) }
                if !devices.isEmpty { sourceButton("iDevice", "apps.ipad") }
            }.padding(2).background(Theme.navy0.opacity(0.4)).clipShape(RoundedRectangle(cornerRadius: 11))
            Divider().frame(height: 20)
            Button { mic.toggle(); if mic { Task { await SCContext.performMicCheck() } } } label: {
                Label { Text("Mic") } icon: { Image(systemName: mic ? "mic.fill" : "mic.slash").frame(width: 18) }
            }.buttonStyle(NavyButton(selected: mic)).accessibilityValue(mic ? "On" : "Off").disabled(microphones.isEmpty)
            if microphones.count > 1 {
                Menu {
                    Picker("Microphone", selection: $micDevice) {
                        Text("System Default").tag("default")
                        ForEach(microphones, id: \.uniqueID) { Text($0.localizedName).tag($0.localizedName) }
                    }.pickerStyle(.inline)
                } label: { Image(systemName: "chevron.down").font(.system(size: 10, weight: .semibold)) }
                    .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().frame(width: 18)
                    .help("Choose microphone").accessibilityLabel("Choose microphone")
                    .onChange(of: micDevice) { _ in mic = true; Task { await SCContext.performMicCheck() } }
            }
            Button { system.toggle() } label: {
                Label { Text("System") } icon: { Image(systemName: system || source == "Audio only" ? "speaker.wave.2.fill" : "speaker.slash").frame(width: 22) }
            }.buttonStyle(NavyButton(selected: system || source == "Audio only"))
                .disabled(source == "Audio only").help(source == "Audio only" ? "Audio-only capture includes system audio" : "System audio")
                .accessibilityValue(system || source == "Audio only" ? "On" : "Off")
            Button {
                if cameraOn { AppDelegate.shared.closeCamera(); SCContext.recordCam = ""; cameraOn = false }
                else { cameraPopover = true }
            } label: { Image(systemName: cameraOn ? "video.fill" : "video") }
                .buttonStyle(NavyButton(selected: cameraOn))
                .help("Camera overlay").accessibilityLabel("Camera overlay")
                .popover(isPresented: $cameraPopover) {
                    CameraPopoverView(closePopover: {
                        cameraPopover = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { cameraOn = !SCContext.recordCam.isEmpty }
                    })
                }
            Menu("Options") {
                Picker("Frame rate", selection: $fps) { ForEach([24, 30, 60, 120], id: \.self) { Text("\($0) fps").tag($0) } }
                Picker("Quality", selection: $quality) {
                    Text("Low").tag(0.3); Text("Medium").tag(0.7); Text("High").tag(1.0)
                }
                Toggle("Show cursor", isOn: $cursor)
                Picker("Format", selection: $format) { Text("MP4").tag("mp4"); Text("MOV").tag("mov") }
                Button("Save folder…") { chooseFolder() }
                Toggle("Each recording in its own folder", isOn: $archiveFolders)
                Toggle("Auto transcribe (Thai)", isOn: $autoTranscribe).disabled(!archiveFolders)
                Toggle("Auto summary (Codex)", isOn: $autoSummary).disabled(!archiveFolders || !autoTranscribe)
                Toggle("Quick = meeting preset (30 fps · H.265 · 1x)", isOn: $quickMeetingPreset)
                Divider()
                Button("Preferences…") { AppDelegate.shared.openSettingPanel() }
                Button("Quit NavyRec") { NSApp.terminate(nil) }
            }.menuStyle(.borderlessButton).fixedSize().padding(.horizontal, 8)
            Divider().frame(height: 20)
            Button("Record", action: begin).buttonStyle(NavyButton(fill: Theme.blue)).keyboardShortcut(.defaultAction)
            Button { AppDelegate.shared.quickRecord() } label: {
                HStack(spacing: 6) {
                    Circle().fill(Color.white).frame(width: 10, height: 10)
                    Text("Quick").fontWeight(.semibold)
                }
            }.buttonStyle(NavyButton(fill: Theme.recFill))
                .help("Record full screen + mic + system audio now (⌘⇧1)")
                .accessibilityLabel("Quick record full screen")
                .popover(isPresented: $devicePopover) { iDevicePopoverView(closePopover: { devicePopover = false }) }
        }.padding(6).font(.system(size: 13)).modifier(NavyPanel())
            .modifier(RecordingStartGate())
            .onReceive(NotificationCenter.default.publisher(for: AVCaptureDevice.wasConnectedNotification)) { _ in refreshDevices() }
            .onReceive(NotificationCenter.default.publisher(for: AVCaptureDevice.wasDisconnectedNotification)) { _ in refreshDevices() }
            .onAppear(perform: refreshDevices)
    }

    private func refreshDevices() {
        devices = SCContext.getiDevice()
        microphones = SCContext.getMicrophone()
        if devices.isEmpty && source == "iDevice" { source = "Screen" }
        if microphones.isEmpty { mic = false }
        if !microphones.contains(where: { $0.localizedName == micDevice }) { micDevice = "default" }
    }

    private func sourceButton(_ name: String, _ icon: String) -> some View {
        // Icon + caption so each mode reads without hovering.
        let caption = ["Audio only": "Audio", "iDevice": "iPhone"][name] ?? name
        return Button { source = name } label: {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 15)).frame(height: 18)
                Text(caption.local).font(.system(size: 10, weight: .medium))
            }.frame(minWidth: 44)
        }
            .buttonStyle(NavyButton(selected: source == name, height: 48))
            .help(name).accessibilityLabel(name).accessibilityValue(source == name ? "Selected" : "")
    }
    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url { ud.set(url.path, forKey: "saveDirectory") }
    }
    private func begin() {
        guard SCContext.canStartRecording else { return }
        refreshDevices()
        let app = AppDelegate.shared
        if source == "iDevice" { devicePopover = true; return }
        closeMainWindow()
        switch source {
        case "Window": app.createNewWindow(view: WinSelector(), title: "Window Selector".local)
        case "App": app.createNewWindow(view: AppSelector(), title: "App Selector".local)
        case "Area":
            SCContext.updateAvailableContent {
                DispatchQueue.main.async {
                    app.showAreaSelector(size: NSSize(width: 600, height: 450))
                    var currentDisplay = SCContext.getSCDisplayWithMouse()
                    mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .rightMouseDown, .leftMouseDown, .otherMouseDown]) { _ in
                        let display = SCContext.getSCDisplayWithMouse()
                        if display != currentDisplay {
                            currentDisplay = display; closeAllWindow()
                            app.showAreaSelector(size: NSSize(width: 600, height: 450))
                        }
                    }
                }
            }
        case "Audio only":
            SCContext.updateAvailableContent {
                DispatchQueue.main.async {
                    refreshDevices()
                    guard let display = SCContext.getSCDisplayWithMouse() else { return }
                    app.createCountdownPanel(screen: display) {
                        app.prepRecord(type: "audio", screens: display, windows: nil, applications: nil)
                    }
                }
            }
        default: app.createNewWindow(view: ScreenSelector(), title: "Screen Selector".local)
        }
    }
}
