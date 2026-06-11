import SwiftUI

@main
struct MacNTFSWriterApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
                .frame(minWidth: 860, minHeight: 560)
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
