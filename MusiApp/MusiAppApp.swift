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
                .environmentObject(container.homeDiscovery)
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
    let homeDiscovery: HomeDiscoveryViewModel
    let player: PlaybackEngine

    init() {
        let library = LibraryViewModel()
        self.library = library
        let itunesProvider = ITunesSearchProvider()
        let providers: [any MusicProvider] = [itunesProvider, BhariyaMusicProvider()]
        search = SearchViewModel(
            coordinator: MusicSearchCoordinator(providers: providers),
            countryCode: { [weak library] in library?.preferences.countryCode ?? "US" }
        )
        homeDiscovery = HomeDiscoveryViewModel(
            provider: itunesProvider,
            countryCode: { [weak library] in library?.preferences.countryCode ?? "US" }
        )
        player = PlaybackEngine()
    }
}
