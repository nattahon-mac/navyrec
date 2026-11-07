//
//  iDeviceSelector.swift
//  NavyRec
//
//  Created by apple on 2024/5/1.
//

import SwiftUI
import AVFoundation

extension AppDelegate {
    func startDeviceOverlayer(size: NSSize = NSSize(width: 200, height: 200)){
        guard let screen = SCContext.getScreenWithMouse() else { return }
        let frame = NSRect(x: (screen.visibleFrame.width-size.width)/2+screen.frame.minX, y: (screen.visibleFrame.height-size.height)/2+screen.frame.minY, width: size.width, height: size.height)
        deviceWindow.contentView = NSHostingView(rootView: SwiftCameraView(type: .idevice))
        deviceWindow.setFrame(frame, display: true)
        deviceWindow.contentView?.wantsLayer = true
        deviceWindow.contentView?.layer?.cornerRadius = 5
        deviceWindow.contentView?.layer?.masksToBounds = true
        deviceWindow.orderFront(self)
    }
}

struct iDevicePopoverView: View {
    var closePopover: () -> Void
    @State private var devices = SCContext.getiDevice()
    @State private var hoverIndex = -1
    @State private var mute = false
    @State private var preset = AVCaptureSession.Preset.high
    //@NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var appDelegate = AppDelegate.shared
    
    var body: some View {
        VStack( alignment: .center, spacing: 0) {
            if devices.count < 1 {
                HStack {
                    ZStack {
                        Circle().frame(width: 26)
                            .foregroundStyle(Theme.text)
                            .opacity(0.2)
                        Image(systemName:"iphone.slash")
                            .foregroundStyle(Theme.text)
                            .font(.system(size: 12))
                    }.padding(.leading, 9)
                    Text("No Devices Found!")
                        .padding(.vertical, 8).padding(.trailing, 10)
                }
                .frame(maxWidth: .infinity)
                NavyDivider().padding(.vertical, 5)
                Text("Connect your device via USB")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.mute)
                    .padding(.bottom, 1)
            } else {
                ForEach(devices.indices, id: \.self) { index in
                    Button(action: {
                        closePopover()
                        closeAllWindow()
                        DispatchQueue.global().async {
                            AVOutputClass.shared.startRecording(with: devices[index], mute: mute, preset: preset)
                        }
                    }, label: {
                        HStack {
                            ZStack {
                                Circle().frame(width: 26)
                                    .foregroundStyle(Theme.text)
                                    .opacity(0.2)
                                Image(systemName:"apple.logo")
                                    .foregroundStyle(Theme.navy0)
                                    .font(.system(size: 12))
                                    .offset(x: -0.5, y:  -0.5)
                            }.padding(.leading, 9)
                            Text(devices[index].localizedName).lineLimit(1).truncationMode(.tail)
                                .frame(maxWidth: 180, alignment: .leading)
                            Text("Record").fontWeight(.semibold)
                                .padding(.vertical, 8).padding(.trailing, 10)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .foregroundStyle(Theme.navy0)
                                .opacity(hoverIndex == index ? 0.1 : 0.0)
                        )
                        .onHover{ hovering in
                            if hoverIndex != index { hoverIndex = index }
                            if !hovering { hoverIndex = -1 }
                        }
                    }).buttonStyle(NavyButton(fill: Theme.blue, foreground: Theme.navy0))
                }
                NavyDivider().padding(.top, 5)
                HStack(spacing: 0) {
                    Text("Mute").font(.system(size: 13)).foregroundStyle(Theme.mute).padding(.trailing, 6)
                    Toggle(isOn: $mute) {}
                        .toggleStyle(.checkbox).tint(Theme.blue)
                        .accessibilityLabel("Mute")

                    Spacer()
                    Text("Preset").font(.system(size: 13)).foregroundStyle(Theme.mute).padding(.trailing, 6)
                    Picker("Preset", selection: $preset) {
                        Text("Low".local).tag(AVCaptureSession.Preset.low)
                        Text("Medium".local).tag(AVCaptureSession.Preset.medium)
                        Text("High".local).tag(AVCaptureSession.Preset.high)
                    }
                    .modifier(NavyOptionPicker())
                }.padding(.vertical, 4).padding(.leading, 10)
                Text("If you are on a call, enable \"Mute\"")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.mute)
                    .padding(.bottom, 1)
            }
        }.padding(12)
        .font(.system(size: 13))
        .background(Theme.navy2)
        .modifier(NavyPanel())
    .modifier(RecordingStartGate())
    }
}

struct ActivityIndicator: View {
    
    @State var currentDegrees = 0.0
    
    let colorGradient = LinearGradient(gradient: Gradient(colors: [
        .secondary, .secondary.opacity(0.75), .secondary.opacity(0.5), .secondary.opacity(0.2), .clear
    ]), startPoint: .leading, endPoint: .trailing)
    
    var body: some View {
        Circle()
            .trim(from: 0.0, to: 0.85)
            .stroke(colorGradient, style: StrokeStyle(lineWidth: 3))
            .frame(width: 18, height: 18)
            .rotationEffect(Angle(degrees: currentDegrees))
            .onAppear {
                Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                    withAnimation {
                        self.currentDegrees += 10
                    }
                }
            }
    }
}


