import AppKit
import SwiftUI

@main
struct CoveApp: App {
    init() {
        if let icon = NSImage(named: "CoveLogo") {
            NSApplication.shared.applicationIconImage = icon
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 920, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
    }
}
