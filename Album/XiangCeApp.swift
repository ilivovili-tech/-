import SwiftUI

@main
struct XiangCeApp: App {
    @StateObject private var library = PhotoLibraryStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(library)
                .preferredColorScheme(nil)
        }
    }
}
