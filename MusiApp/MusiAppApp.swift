import SwiftUI
import Combine

@main
struct MusiAppApp: App {
    @StateObject private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            AppShell()
                .environmentObject(container.library)
                .environmentObject(container.search)
                .environmentObject(container.player)
                .preferredColorScheme(.dark)
                .tint(MusiTheme.accent)
        }
    }
}

@MainActor
final class AppContainer: ObservableObject {
    let library: LibraryViewModel
    let search: SearchViewModel
    let player: PlaybackEngine

    init() {
        let library = LibraryViewModel()
        self.library = library
        let providers: [any MusicProvider] = [ITunesSearchProvider(), BhariyaMusicProvider()]
        search = SearchViewModel(
            coordinator: MusicSearchCoordinator(providers: providers),
            countryCode: { [weak library] in library?.preferences.countryCode ?? "US" }
        )
        player = PlaybackEngine()
    }
}
