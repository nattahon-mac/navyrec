//
//  StatusBarItem.swift
//  NavyRec
//
//  Created by apple on 2024/4/16.
//

import SwiftUI

class PopoverState: ObservableObject {
    static let shared = PopoverState()
    @Published var isShowing: Bool = false
    @Published var isPaused: Bool = false
}

// Native status-button event handling avoids SwiftUI hosting-view hit testing on macOS 27.
func updateStatusBar() {
    DispatchQueue.main.async {
        guard let item = statusBarItem, let button = item.button else { return }
        let finishing = RecordingLifecycle.shared.isFinalizing
        let recording = SCContext.streamType != nil
        item.isVisible = recording || finishing || ud.bool(forKey: "showMenubar")
        item.length = NSStatusItem.variableLength
        button.subviews = []
        button.image = NSImage(systemSymbolName: recording ? "circle.fill" : "record.circle",
                               accessibilityDescription: "NavyRec")
        button.contentTintColor = recording ? NSColor(Theme.rec) : nil
        button.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        button.title = finishing ? " Saving…" : ""
        button.toolTip = recording ? "NavyRec — click to stop; right-click for menu" : "NavyRec"
        button.target = AppDelegate.shared
        button.action = #selector(AppDelegate.statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.setAccessibilityLabel(recording ? "Stop NavyRec recording" : "NavyRec")
    }
}

extension AppDelegate {
    @objc func statusItemClicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type != .rightMouseUp && SCContext.streamType != nil {
            SCContext.stopAnyRecording()
            return
        }
        let menu = NSMenu()
        if SCContext.streamType != nil {
            let stop = menu.addItem(withTitle: "Stop Recording".local,
                                    action: #selector(stopFromStatusMenu), keyEquivalent: "")
            stop.target = self
            stop.isEnabled = !RecordingLifecycle.shared.isFinalizing
            if SCContext.streamType != .idevice {
                let pause = menu.addItem(withTitle: "Pause / Resume".local,
                                        action: #selector(pauseFromStatusMenu), keyEquivalent: "")
                pause.target = self
                pause.isEnabled = !RecordingLifecycle.shared.isFinalizing
            }
        }
        if SCContext.streamType != nil && !RecordingLifecycle.shared.isFinalizing {
            let controls = menu.addItem(withTitle: "Recording Controller".local,
                                        action: #selector(showRecordingControls), keyEquivalent: "")
            controls.target = self
        }
        menu.autoenablesItems = false
        let quick = menu.addItem(withTitle: "Quick Record (Full Screen)",
                                 action: #selector(AppDelegate.quickRecord), keyEquivalent: "")
        quick.target = AppDelegate.shared
        quick.isEnabled = SCContext.canStartRecording
        let open = menu.addItem(withTitle: "Open Main Panel".local,
                                action: #selector(openFromStatusMenu), keyEquivalent: "")
        open.target = self
        open.isEnabled = SCContext.canStartRecording
        menu.addItem(.separator())
        let quit = menu.addItem(withTitle: "Quit NavyRec", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        quit.target = NSApp
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.minY), in: sender)
    }

    @objc func showRecordingControls() {
        StudioController.shared.show()
    }

    @objc private func stopFromStatusMenu() { SCContext.stopAnyRecording() }
    @objc private func pauseFromStatusMenu() { SCContext.pauseRecording() }
    @objc private func openFromStatusMenu() {
        _ = applicationShouldHandleReopen(NSApp, hasVisibleWindows: true)
        NSApp.activate(ignoringOtherApps: true)
    }
}
