import SwiftUI
import AVKit

struct ContentView: View {
    @EnvironmentObject var model: PlayerModel

    var body: some View {
        TabView {
            PlaylistsView()
                .tabItem { Label("Playlists", systemImage: "list.bullet.rectangle") }
            FavoritesView()
                .tabItem { Label("Favorites", systemImage: "star.fill") }
            LocalView()
                .tabItem { Label("Local", systemImage: "folder.fill") }
            CastView()
                .tabItem { Label("Cast", systemImage: "airplayvideo") }
        }
        .fullScreenCover(isPresented: $model.showFullPlayer) {
            PlayerScreen()
        }
        .alert(
            "Can't play this",
            isPresented: Binding(
                get: { model.errorMessage != nil && !model.showFullPlayer },
                set: { if !$0 { model.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
    }
}

/// Small bar above the tab bar that keeps playback visible while browsing.
struct MiniPlayerBar: View {
    @EnvironmentObject var model: PlayerModel

    var body: some View {
        if let current = model.current, !model.showFullPlayer {
            HStack(spacing: 12) {
                PlayerLayerView(player: model.player)
                    .frame(width: 64, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                Text(current.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                Spacer()

                Button {
                    model.togglePlayPause()
                } label: {
                    Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
                        .frame(width: 36, height: 36)
                }

                Button {
                    model.stop()
                } label: {
                    Image(systemName: "xmark")
                        .frame(width: 36, height: 36)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.regularMaterial)
            .contentShape(Rectangle())
            .onTapGesture { model.showFullPlayer = true }
        }
    }
}

extension View {
    /// Shows the mini player above the tab bar while something is playing.
    func miniPlayerInset() -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) { MiniPlayerBar() }
    }
}
