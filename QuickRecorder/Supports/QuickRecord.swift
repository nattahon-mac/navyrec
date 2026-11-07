//
//  QuickRecord.swift
//  NavyRec
//
//  One action: full screen under the pointer + current mic + system audio,
//  no selector, no countdown.
//

import AppKit
import ScreenCaptureKit

extension AppDelegate {
    @objc func quickRecord() { startQuickRecord(audioOnly: false) }

    func startQuickRecord(audioOnly: Bool) {
        guard SCContext.canStartRecording else { return }
        let ud = UserDefaults.standard
        ud.set(!SCContext.getMicrophone().isEmpty, forKey: "recordMic")
        ud.set(true, forKey: "recordWinSound")
        SCContext.updateAvailableContent {
            DispatchQueue.main.async {
                closeAllWindow()
                guard let display = SCContext.getSCDisplayWithMouse() ?? SCContext.availableContent?.displays.first else { return }
                if ud.bool(forKey: "recordMic") { Task { await SCContext.performMicCheck() } }
                SCContext.meetingPreset = ud.object(forKey: "quickMeetingPreset") as? Bool ?? true
                self.prepRecord(type: audioOnly ? "audio" : "display", screens: display, windows: nil, applications: nil, fastStart: true)
            }
        }
    }
}

class quickRecordCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        DispatchQueue.main.async { AppDelegate.shared.quickRecord() }
        return nil
    }
}

class stopRecordingCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        DispatchQueue.main.async { SCContext.stopAnyRecording() }
        return nil
    }
}
