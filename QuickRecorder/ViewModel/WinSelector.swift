//
//  WinSelector.swift
//  NavyRec
//
//  Created by apple on 2024/4/17.
//

import SwiftUI
import Foundation
import AVFoundation
import ScreenCaptureKit

struct WinSelector: View {
    @Environment(\.colorScheme) var colorScheme
    @StateObject var viewModel = WindowSelectorViewModel()
    @State private var selected = [SCWindow]()
    @State private var display: SCDisplay!
    @State private var selectedTab = 0
    @State private var isPopoverShowing = false
    @State private var isPopoverShowing2 = false
    @State private var disableFilter = false
    @State private var donotCapture = false
    @State private var autoStop = 0
    var appDelegate = AppDelegate.shared
    
    var body: some View {
        ZStack {
            VStack(spacing: 10) {
                if #available(macOS 15, *) {
                    Text("Please select the window(s) to record").offset(y: 12)
                } else {
                    HStack {
                        Spacer()
                        Text("Please select the window(s) to record")
                        Spacer()
                        HoverButton(action: {
                            WindowHighlighter.shared.registerMouseMonitor(mode: 2)
                        }, label: {
                            ZStack {
                                Color.white.opacity(0.0001)
                                Image(systemName: "macwindow.and.cursorarrow")
                                    .resizable().scaledToFit()
                            }.frame(width: 20, height: 20)
                        })
                        .help("Select Window Directly")
                        .padding(.leading, -20)
                    }.padding(.horizontal, 10)
                }
                TabView(selection: $selectedTab) {
                    let allApps = viewModel.windowThumbnails.sorted(by: { $0.key.displayID < $1.key.displayID })
                    ForEach(allApps, id: \.key) { element in
                        let (screen, thumbnails) = element
                        let index = allApps.firstIndex(where: { $0.key == screen }) ?? 0
                        ScrollView(.vertical) {
                            VStack(spacing: 0) {
                                ForEach(0..<thumbnails.count/4 + 1, id: \.self) { rowIndex in
                                    HStack(spacing: 16.5) {
                                        ForEach(0..<4, id: \.self) { columnIndex in
                                            let index = 4 * rowIndex + columnIndex
                                            if index <= thumbnails.count - 1 {
                                                let item = thumbnails[index]
                                                Button(action: {
                                                    if !selected.contains(item.window) {
                                                        selected.append(item.window)
                                                    } else {
                                                        selected.removeAll{ $0 == item.window }
                                                    }
                                                }, label: {
                                                    VStack(spacing: 1){
                                                        ZStack{
                                                            if colorScheme == .light {
                                                                Image(nsImage: item.image)
                                                                    .resizable()
                                                                    .aspectRatio(contentMode: .fit)
                                                                    .colorMultiply(.black)
                                                                    .blur(radius: 0.5)
                                                                    .opacity(1)
                                                                    .frame(width: 160, height: 90, alignment: .center)
                                                            } else {
                                                                Image(nsImage: item.image)
                                                                    .resizable()
                                                                    .aspectRatio(contentMode: .fit)
                                                                    .colorMultiply(.black)
                                                                    .colorInvert()
                                                                    .blur(radius: 0.5)
                                                                    .opacity(1)
                                                                    .frame(width: 160, height: 90, alignment: .center)
                                                            }
                                                            Image(nsImage: item.image)
                                                                .resizable()
                                                                .aspectRatio(contentMode: .fit)
                                                                .frame(width: 160, height: 90, alignment: .center)
                                                            Image(systemName: "circle.fill")
                                                                .font(.system(size: 31))
                                                                .foregroundStyle(Theme.navy1)
                                                                .opacity(selected.contains(item.window) ? 1.0 : 0.0)
                                                                .offset(x: 55, y: 25)
                                                            Image(systemName: "checkmark.circle.fill")
                                                                .font(.system(size: 27))
                                                                .foregroundStyle(Theme.ice)
                                                                .opacity(selected.contains(item.window) ? 1.0 : 0.0)
                                                                .offset(x: 55, y: 25)
                                                            Image(nsImage: SCContext.getAppIcon(item.window.owningApplication!)!)
                                                                .resizable()
                                                                .aspectRatio(contentMode: .fit)
                                                                .frame(width: 40, height: 40, alignment: .center)
                                                                .offset(y: 35)
                                                        }
                                                        .padding(5)
                                                        .padding(.vertical, 5)
                                                        .modifier(NavyThumbnail(selected: selected.contains(item.window)))
                                                        Text(item.window.title!)
                                                            .font(.system(size: 12))
                                                            .foregroundStyle(Theme.text)
                                                            .lineLimit(1)
                                                            .truncationMode(.tail)
                                                            .frame(width: 160)
                                                    }
                                                }).buttonStyle(.plain)
                                            }
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.leading, 12).padding(.top, 5)
                                }
                            }
                        }
                        .tag(index)
                        .tabItem { Text(screen.nsScreen?.localizedName ?? ("Display ".local + "\(index)")) }
                        .onAppear{ display = screen }
                    }
                }
                .frame(height: 320)
                .padding(.horizontal, 10)
                .onChange(of: selectedTab) { _ in selected.removeAll() }
                .onReceive(viewModel.$isReady) { isReady in
                    if isReady {
                        let allApps = viewModel.windowThumbnails.sorted(by: { $0.key.displayID < $1.key.displayID })
                        if let s = NSApp.windows.first(where: { $0.title == "Window Selector".local })?.screen,
                           let index = allApps.firstIndex(where: { $0.key.displayID == s.displayID }) {
                            selectedTab = index
                        }
                    }
                }
                NavyDivider().padding(.horizontal, 16)
                OptionsView()
                HStack(spacing: 4) {
                    Button(action: {
                        self.viewModel.setupStreams(filter: !disableFilter, capture: !donotCapture)
                        self.selected.removeAll()
                    }, label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                        
                    }).buttonStyle(NavyButton(border: Theme.mute))
                    Button(action: {
                        isPopoverShowing2 = true
                    }, label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.text)
                    })
                    .buttonStyle(NavyButton(border: Theme.mute, height: 28))
                    .accessibilityLabel("Window filter options")
                    .popover(isPresented: $isPopoverShowing2, arrowEdge: .bottom, content: {
                        VStack(alignment: .leading) {
                            Toggle(isOn: $disableFilter) { Text("Show Windows with No Title") }
                                .toggleStyle(.checkbox).tint(Theme.blue)
                                .onChange(of: disableFilter) { _ in
                                    self.viewModel.setupStreams(filter: !disableFilter, capture: !donotCapture)
                                    self.selected.removeAll()
                                }
                            Toggle(isOn: $donotCapture) { Text("Don't Create Thumbnails") }
                                .toggleStyle(.checkbox).tint(Theme.blue)
                                .onChange(of: donotCapture) { _ in
                                    self.viewModel.setupStreams(filter: !disableFilter, capture: !donotCapture)
                                    self.selected.removeAll()
                                }
                        }
                        .fixedSize()
                        .padding()
                        .font(.system(size: 13))
                        .background(Theme.navy2)
                        .modifier(NavyPanel())
                    })
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
                    .disabled(selected.count < 1)
                }.padding(.horizontal, 16)
                Spacer()
            }.padding(.top, 12)
        }
        .frame(width: 780, height:555)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                HoverButton(action: {
                    WindowHighlighter.shared.registerMouseMonitor()
                }, label: {
                    Image(systemName: "macwindow.and.cursorarrow")
                        .resizable().scaledToFit()
                        .frame(width: 20)
                }).help("Select Window Directly")
            }
        }
    .font(.system(size: 13))
    .tint(Theme.blue)
    .background(Theme.navy2)
    .modifier(NavyPanel())
    .modifier(RecordingStartGate())
    }
    
    func startRecording() {
        guard SCContext.canStartRecording else { return }
        closeAllWindow()
        appDelegate.createCountdownPanel(screen: display) {
            SCContext.autoStop = autoStop
            appDelegate.prepRecord(type: (selected.count<2 ? "window" : "windows") , screens: display, windows: selected, applications: nil)
        }
    }
}

class WindowSelectorViewModel: NSObject, ObservableObject, SCStreamDelegate, SCStreamOutput {
    @Published var windowThumbnails = [SCDisplay:[WindowThumbnail]]()
    @Published var isReady = false
    private var allWindows = [SCWindow]()
    private var streams = [SCStream]()
    
    override init() {
        super.init()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.setupStreams()
        }
    }
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        if CMSampleBufferGetImageBuffer(sampleBuffer) == nil { return }
        let nsImage = sampleBuffer.nsImage ?? (resourceImage(named: "unknowScreen") ?? NSImage())
        if let index = self.streams.firstIndex(of: stream), index + 1 <= self.allWindows.count {
            let currentWindow = self.allWindows[index]
            let thumbnail = WindowThumbnail(image: nsImage, window: currentWindow)
            guard let displays = SCContext.availableContent?.displays.filter({ NSIntersectsRect(currentWindow.frame, $0.frame) }) else {
                self.streams[index].stopCapture()
                return
            }
            for d in displays {
                DispatchQueue.main.async {
                    if self.windowThumbnails[d] != nil {
                        if !self.windowThumbnails[d]!.contains(where: { $0.window == currentWindow }) { self.windowThumbnails[d]!.append(thumbnail) }
                    } else {
                        self.windowThumbnails[d] = [thumbnail]
                    }
                }
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) { self.streams[index].stopCapture() }
            if index + 1 == self.streams.count { DispatchQueue.main.async { self.isReady = true }}
        }
    }

    func setupStreams(filter: Bool = true, capture: Bool = true) {
        SCContext.updateAvailableContent {
            Task {
                do {
                    self.streams.removeAll()
                    DispatchQueue.main.async { self.windowThumbnails.removeAll() }
                    self.allWindows = SCContext.getWindows().filter({
                        !($0.title == "" && $0.owningApplication?.bundleIdentifier == "com.apple.finder")
                        && $0.owningApplication?.bundleIdentifier != Bundle.main.bundleIdentifier
                        && $0.owningApplication?.applicationName != ""
                    })
                    if filter { self.allWindows = self.allWindows.filter({ $0.title != "" }) }
                    if capture {
                        let contentFilters = self.allWindows.map { SCContentFilter(desktopIndependentWindow: $0) }
                        for (index, contentFilter) in contentFilters.enumerated() {
                            let streamConfiguration = SCStreamConfiguration()
                            let width = self.allWindows[index].frame.width
                            let height = self.allWindows[index].frame.height
                            var factor = 0.5
                            if width < 200 && height < 200 { factor = 1.0 }
                            streamConfiguration.width = Int(width * factor)
                            streamConfiguration.height = Int(height * factor)
                            streamConfiguration.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(1))
                            streamConfiguration.pixelFormat = kCVPixelFormatType_32BGRA
                            if #available(macOS 13, *) { streamConfiguration.capturesAudio = false }
                            streamConfiguration.showsCursor = false
                            streamConfiguration.scalesToFit = true
                            streamConfiguration.queueDepth = 3
                            let stream = SCStream(filter: contentFilter, configuration: streamConfiguration, delegate: self)
                            try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: .main)
                            try await stream.startCapture()
                            self.streams.append(stream)
                        }
                    } else {
                        for w in self.allWindows {
                            let thumbnail = WindowThumbnail(image: (resourceImage(named: "unknowScreen") ?? NSImage()), window: w)
                            guard let displays = SCContext.availableContent?.displays.filter({ NSIntersectsRect(w.frame, $0.frame) }) else { break }
                            for d in displays {
                                DispatchQueue.main.async {
                                    if self.windowThumbnails[d] != nil {
                                        if !self.windowThumbnails[d]!.contains(where: { $0.window == w }) {
                                            self.windowThumbnails[d]!.append(thumbnail)
                                        }
                                    } else {
                                        self.windowThumbnails[d] = [thumbnail]
                                    }
                                }
                            }
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { self.isReady = true }
                    }
                } catch {
                    print("Get windowshot error：\(error)")
                }
            }
        }
    }
}

class WindowThumbnail {
    let image: NSImage
    let window: SCWindow

    init(image: NSImage, window: SCWindow) {
        self.image = image
        self.window = window
    }
}
