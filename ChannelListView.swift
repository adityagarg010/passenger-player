import SwiftUI

struct ChannelListView: View {
    let playlistID: UUID

    @EnvironmentObject var library: LibraryStore
    @EnvironmentObject var model: PlayerModel
    @State private var search = ""
    @State private var group: String?

    private var playlist: Playlist? {
        library.playlists.first { $0.id == playlistID }
    }

    var body: some View {
        Group {
            if let playlist {
                let channels = filtered(playlist)
                List(channels) { channel in
                    ChannelRow(channel: channel) {
                        model.open(channel, in: channels)
                    }
                }
                .listStyle(.plain)
                .overlay {
                    if channels.isEmpty { ContentUnavailableView.search(text: search) }
                }
                .searchable(text: $search, prompt: "Search channels")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        groupMenu(playlist)
                    }
                }
            } else {
                ContentUnavailableView("Playlist not found", systemImage: "questionmark.folder")
            }
        }
        .navigationTitle(playlist?.name ?? "Playlist")
        .navigationBarTitleDisplayMode(.inline)
        .miniPlayerInset()
    }

    private func filtered(_ playlist: Playlist) -> [Channel] {
        playlist.channels.filter { channel in
            (group == nil || channel.group == group)
                && (search.isEmpty || channel.name.localizedCaseInsensitiveContains(search))
        }
    }

    private func groupMenu(_ playlist: Playlist) -> some View {
        Menu {
            Picker("Group", selection: $group) {
                Text("All groups").tag(String?.none)
                ForEach(playlist.groups, id: \.self) { name in
                    Text(name).tag(Optional(name))
                }
            }
        } label: {
            Image(systemName: group == nil
                  ? "line.3.horizontal.decrease.circle"
                  : "line.3.horizontal.decrease.circle.fill")
        }
    }
}

struct FavoritesView: View {
    @EnvironmentObject var library: LibraryStore
    @EnvironmentObject var model: PlayerModel

    var body: some View {
        NavigationStack {
            Group {
                if library.favorites.isEmpty {
                    ContentUnavailableView(
                        "No favorites yet",
                        systemImage: "star",
                        description: Text("Tap the star next to a channel to keep it here.")
                    )
                } else {
                    List(library.favorites) { channel in
                        ChannelRow(channel: channel) {
                            model.open(channel, in: library.favorites)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Favorites")
            .miniPlayerInset()
        }
    }
}

struct ChannelRow: View {
    let channel: Channel
    let onPlay: () -> Void

    @EnvironmentObject var library: LibraryStore

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 12) {
                AsyncImage(url: channel.logo) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFit()
                    default:
                        Image(systemName: "tv").foregroundStyle(.secondary)
                    }
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text(channel.name).lineLimit(1)
                    Text(channel.group)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onPlay)

            Button {
                library.toggleFavorite(channel)
            } label: {
                Image(systemName: library.isFavorite(channel) ? "star.fill" : "star")
                    .foregroundStyle(library.isFavorite(channel) ? Color.yellow : Color.secondary)
            }
            .buttonStyle(.borderless)
        }
    }
}
