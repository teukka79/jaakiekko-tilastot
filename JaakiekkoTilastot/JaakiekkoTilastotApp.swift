import SwiftUI

@main
struct JaakiekkoTilastotApp: App {
    @State private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .preferredColorScheme(.dark)
                .frame(minWidth: 1150, minHeight: 700)
                .onAppear { store.appIconChoice.apply() }
        }
        .windowStyle(.hiddenTitleBar)
    }
}
