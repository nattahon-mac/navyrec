//
//  ScreenSelector.swift
//  NavyRec
//
//  Created by apple on 2024/4/18.
//

import SwiftUI
import ScreenCaptureKit

struct ScreenSelector: View {
    @Environment(\.colorScheme) var colorScheme
    @StateObject var viewModel = ScreenSelectorViewModel()
    
    @State private var selected: SCDisplay?
    @State private var isPopoverShowing = false
    @State private var autoStop = 0
    var appDelegate = AppDelegate.shared
    
    var body: some View {
        ZStack {
            VStack(spacing: 10) {
                Text("Please select the screen to record")
                let count = viewModel.screenThumbnails.count
                ScrollView(.vertical) {
                    VStack(spacing: 14){
                        ForEach(0..<viewModel.screenThumbnails.count/2 + 1, id: \.self) { rowIndex in
                            HStack(spacing: 30) {
                                ForEach(0..<2, id: \.self) { columnIndex in
                                    let index = 2 * rowIndex + columnIndex
                                    if index <= viewModel.screenThumbnails.count - 1 {
                                        Button(action: {
                                            selected = viewModel.screenThumbnails[index].screen
                                        }, label: {
                                            ZStack {
                                                VStack(spacing: 4) {
                                                    ZStack{
                                                        if colorScheme == .light {
                                                            Image(nsImage: viewModel.screenThumbnails[index].image)
                                                                .resizable()
                                                                .aspectRatio(contentMode: .fit)
                                                                .colorMultiply(.black)
                                                                .blur(radius: 0.5)
                                                                .opacity(1)
                                                        } else {
                                                            Image(nsImage: viewModel.screenThumbnails[index].image)
                                                                .resizable()
                                                                .aspectRatio(contentMode: .fit)
                                                                .colorMultiply(.black)
                                                                .colorInvert()
                                                                .blur(radius: 0.5)
                                                                .opacity(1)
                                                        }
                                                        Image(nsImage: viewModel.screenThumbnails[index].image)
                                                            .resizable()
                                                            .aspectRatio(contentMode: .fit)
                                                    }.frame(width: count == 1 ? 480 : 320, height: count == 1 ? 270 : 180, alignment: .center)
                                                    let screenName = NSScreen.screens.first(where: { $0.displayID == viewModel.screenThumbnails[index].screen.displayID })?.localizedName ?? "Display ".local + "\(viewModel.screenThumbnails[index].screen.displayID)"
                                                    Text(screenName)
                                                        .font(.system(size: 12))
                                                        .foregroundStyle(Theme.text)
                                                        .lineLimit(1)
                                                        .truncationMode(.tail)
                                                        .offset(y:count == 1 ? 5 : 2)
                                                }
                                                .padding(count == 1 ? 19 : 10)
                                                .modifier(NavyThumbnail(selected: (selected == viewModel.screenThumbnails[index].screen)))
                                                Group {
                                                    Image(systemName: "circle.fill")
                                                        .font(.system(size: count == 1 ? 62 : 31))
                                                        .foregroundStyle(Theme.navy1)
                                                        .opacity((selected == viewModel.screenThumbnails[index].screen) ? 1.0 : 0.0)
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .font(.system(size: count == 1 ? 54 : 27))
                                                        .foregroundStyle(Theme.ice)
                                                        .opacity((selected == viewModel.screenThumbnails[index].screen) ? 1.0 : 0.0)
                                                }.offset(x: count == 1 ? 200 : 120, y: count == 1 ? 95 : 50)
                                            }
                                        }).buttonStyle(.plain)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 35)
                        }
                    }
                }
                .frame(height: 320)
                
                NavyDivider().padding(.horizontal, 16)
                OptionsView()
                HStack(spacing: 4) {
                    Button(action: {
                        viewModel.setupStreams()
                    }, label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                        
                    }).buttonStyle(NavyButton(border: Theme.mute))
                    Spacer()
                    Button(action: {
                        isPopoverShowing = true
                    }, label: {
                        Image(systemName: "timer")
                    })
                    .buttonStyle(NavyButton(border: Theme.mute, height: 28))
                    .help("Stop after")
                    .accessibilityLabel("Stop after")

                    .popover(isPresented: $isPopoverShowing, arrowEdge: .bottom, content: {
                        HStack {
                            Text(" Stop after".local)
                            TextField("", value: $autoStop, formatter: NumberFormatter())
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            Stepper("", value: $autoStop)
                                .padding(.leading, -10)
                            Text("minutes ".local)
                        }
                        .fixedSize()
                        .padding()
                        .font(.system(size: 13))
                        .background(Theme.navy2)
                        .modifier(NavyPanel())
                    })
                    Button(action: {
                        startRecording()
                    }, label: {
                        Text("Record")
                    }).buttonStyle(NavyButton(fill: Theme.blue, foreground: Theme.navy0))
                    .disabled(selected == nil)
                }.padding(.horizontal, 16)
                Spacer()
            }
            .padding(.top, 12)
        }.frame(width: 780, height:555)
    .font(.system(size: 13))
    .tint(Theme.blue)
    .background(Theme.navy2)
    .modifier(NavyPanel())
    .modifier(RecordingStartGate())
    }
    
    func startRecording() {
        guard SCContext.canStartRecording else { return }
        closeAllWindow()
        if let screen = selected {
            appDelegate.createCountdownPanel(screen: screen) {
                SCContext.autoStop = autoStop
                appDelegate.prepRecord(type: "display", screens: screen, windows: nil, applications: nil)
            }
        }
    }
}

class ScreenSelectorViewModel: NSObject, ObservableObject, SCStreamDelegate, SCStreamOutput {
    @Published var screenThumbnails = [ScreenThumbnail]()
    private var allScreens = [SCDisplay]()
    private var streams = [SCStream]()
    
    override init() {
        super.init()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.setupStreams()
        }
    }
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        if CMSampleBufferGetImageBuffer(sampleBuffer) == nil { return }
        var nsImage = sampleBuffer.nsImage
        if let index = self.streams.firstIndex(of: stream), index + 1 <= self.allScreens.count {
            if nsImage == nil { nsImage = SCContext.getWallpaper(self.allScreens[index]) ?? (resourceImage(named: "unknowScreen") ?? NSImage()) }
            let currentScreen = self.allScreens[index]
            let thumbnail = ScreenThumbnail(image: nsImage!, screen: currentScreen)
            DispatchQueue.main.async {
                if !self.screenThumbnails.contains(where: { $0.screen == currentScreen }) { self.screenThumbnails.append(thumbnail) }
            }
            self.streams[index].stopCapture()
        }
    }

    func setupStreams() {
        SCContext.updateAvailableContent {
            Task {
                do {
                    self.streams.removeAll()
                    DispatchQueue.main.async { self.screenThumbnails.removeAll() }
                    guard let screens = SCContext.availableContent?.displays else { return }
                    self.allScreens = screens
                    let qrSelf = SCContext.getSelf()
                    let contentFilters = self.allScreens.map { SCContentFilter(display: $0, excludingApplications: qrSelf != nil ? [qrSelf!] : [], exceptingWindows: []) }
                    for (index, contentFilter) in contentFilters.enumerated() {
                        let streamConfiguration = SCStreamConfiguration()
                        streamConfiguration.width = Int(self.allScreens[index].frame.width)
                        streamConfiguration.height = Int(self.allScreens[index].frame.height)
                        streamConfiguration.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(1))
                        streamConfiguration.pixelFormat = kCVPixelFormatType_32BGRA
                        if #available(macOS 13, *) { streamConfiguration.capturesAudio = false }
                        streamConfiguration.showsCursor = false
                        streamConfiguration.queueDepth = 3
                        let stream = SCStream(filter: contentFilter, configuration: streamConfiguration, delegate: self)
                        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: .main)
                        try await stream.startCapture()
                        self.streams.append(stream)
                    }
                } catch {
                    print("Get screenshot error：\(error)")
                }
            }
        }
    }
}

class ScreenThumbnail {
    let image: NSImage
    let screen: SCDisplay

    init(image: NSImage, screen: SCDisplay) {
        self.image = image
        self.screen = screen
    }
}
