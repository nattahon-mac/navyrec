import SwiftUI

func resourceImage(named name: String) -> NSImage? {
    Bundle.navyResources.url(forResource: name, withExtension: "png").flatMap { NSImage(contentsOf: $0) }
}

extension Color {
    static let mygreen = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(srgbRed: 0.23921568627450981, green: 0.8823529411764706, blue: 0.3333333333333333, alpha: 1) : NSColor(srgbRed: 0.12941176470588237, green: 0.7647058823529411, blue: 0.21568627450980393, alpha: 1)
    })
    static let mypurple = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(displayP3Red: 0.3843137254901961, green: 0.3803921568627451, blue: 0.9176470588235294, alpha: 1) : NSColor(displayP3Red: 0.3411764705882353, green: 0.33725490196078434, blue: 0.8117647058823529, alpha: 1)
    })
    static let buttonRedDark = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(displayP3Red: 0.803921568627451, green: 0.22745098039215686, blue: 0.16862745098039217, alpha: 1) : NSColor(displayP3Red: 0.803921568627451, green: 0.22745098039215686, blue: 0.16862745098039217, alpha: 1)
    })
    static let myblue = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(srgbRed: 0.3176470588235294, green: 0.7333333333333333, blue: 0.9647058823529412, alpha: 1) : NSColor(srgbRed: 0.23921568627450981, green: 0.6549019607843137, blue: 0.8823529411764706, alpha: 1)
    })
    static let blackWhite = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(displayP3Red: 0.0, green: 0.0, blue: 0.0, alpha: 1) : NSColor(displayP3Red: 1.0, green: 1.0, blue: 1.0, alpha: 1)
    })
    static let buttonRed = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(displayP3Red: 0.9254901960784314, green: 0.41568627450980394, blue: 0.3686274509803922, alpha: 1) : NSColor(displayP3Red: 0.9254901960784314, green: 0.41568627450980394, blue: 0.3686274509803922, alpha: 1)
    })
    static let darkMyRed = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(displayP3Red: 0.9254901960784314, green: 0.41568627450980394, blue: 0.36470588235294116, alpha: 1) : NSColor(displayP3Red: 0.6666666666666666, green: 0.10588235294117647, blue: 0.047058823529411764, alpha: 1)
    })
}
// SwiftPM's executable accessor searches the app root; signed macOS apps keep resources
// under Contents/Resources. Fall back to Bundle.module for `swift run`/CLI builds.
extension Bundle {
    static let navyResources: Bundle = {
        if let url = Bundle.main.resourceURL?.appendingPathComponent("NavyRec_NavyRec.bundle"),
           let bundle = Bundle(url: url) { return bundle }
        return .module
    }()
}
