import SwiftUI
import UniformTypeIdentifiers

struct PlaylistsView: View {
    @EnvironmentObject var library: LibraryStore

    @State private var showAdd = false
    @State private var showRename = false
    @State private var renamingID: UUID?
    @State private var renameText = ""
    @State private var refreshingID: UUID?
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            Group {
                if library.playlists.isEmpty {
                    ContentUnavailableView {
                        Label("No playlists yet", systemImage: "list.bullet.rectangle")
                    } description: {
                        Text("Add your own M3U or M3U8 link, QR code or file.")
                    } actions: {
                        Button("Add playlist") { showAdd = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    List(library.playlists) { playlist in
                        NavigationLink(value: playlist.id) {
                            row(playlist)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                library.delete(playlist)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            if playlist.sourceURL != nil {
                                Button {
                                    refresh(playlist)
                                } label: {
                                    Label("Refresh", systemImage: "arrow.clockwise")
                                }
                                .tint(.blue)
                            }
                        }
                        .contextMenu {
                            Button {
                                renamingID = playlist.id
                                renameText = playlist.name
                                showRename = true
                            } label: {
                                Label("Rename", systemImage: "pencil")
                            }
                            if playlist.sourceURL != nil {
                                Button {
                                    refresh(playlist)
                                } label: {
                                    Label("Refresh", systemImage: "arrow.clockwise")
                                }
                            }
                            Button(role: .destructive) {
                                library.delete(playlist)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Playlists")
            .navigationDestination(for: UUID.self) { id in
                ChannelListView(playlistID: id)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showAdd) { AddPlaylistView() }
            .alert("Rename playlist", isPresented: $showRename) {
                TextField("Name", text: $renameText)
                Button("Save") {
                    if let id = renamingID { library.rename(id, to: renameText) }
                }
                Button("Cancel", role: .cancel) {}
            }
            .alert(
                "Couldn't refresh",
                isPresented: Binding(get: { errorText != nil }, set: { if !$0 { errorText = nil } })
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorText ?? "")
            }
            .miniPlayerInset()
        }
    }

    private func row(_ playlist: Playlist) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(playlist.name).font(.headline)
                (Text("\(playlist.channels.count) channels · updated ")
                    + Text(playlist.updatedAt, style: .relative)
                    + Text(" ago"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if refreshingID == playlist.id {
                Spacer()
                ProgressView()
            }
        }
    }

    private func refresh(_ playlist: Playlist) {
        refreshingID = playlist.id
        Task {
            do {
                try await library.refresh(playlist)
            } catch {
                errorText = error.localizedDescription
            }
            refreshingID = nil
        }
    }
}

struct AddPlaylistView: View {
    @EnvironmentObject var library: LibraryStore
    @Environment(\.dismiss) private var dismiss

    @State private var urlText = ""
    @State private var name = ""
    @State private var isLoading = false
    @State private var errorText: String?
    @State private var showScanner = false
    @State private var showFileImporter = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Playlist link") {
                    TextField("https://example.com/playlist.m3u", text: $urlText)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Name (optional)", text: $name)
                    HStack {
                        Button("Paste") {
                            if let pasted = UIPasteboard.general.string { urlText = pasted }
                        }
                        Spacer()
                        Button {
                            showScanner = true
                        } label: {
                            Label("Scan QR", systemImage: "qrcode.viewfinder")
                        }
                    }
                    .buttonStyle(.borderless)
                }

                Section {
                    Button {
                        addFromLink()
                    } label: {
                        if isLoading {
                            HStack {
                                ProgressView()
                                Text("Loading playlist…")
                            }
                        } else {
                            Text("Add playlist")
                        }
                    }
                    .disabled(urlText.nonEmpty == nil || isLoading)

                    Button("Choose a file…") { showFileImporter = true }
                        .disabled(isLoading)
                } footer: {
                    Text("Add your own playlist. This app doesn't include any channels or content.")
                }

                if let errorText {
                    Section { Text(errorText).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Add playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showScanner) { scanner }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.m3uPlaylist, .plainText, .data]
            ) { result in
                switch result {
                case .success(let url):
                    do {
                        try library.addPlaylist(fileURL: url)
                        dismiss()
                    } catch {
                        errorText = error.localizedDescription
                    }
                case .failure(let error):
                    errorText = error.localizedDescription
                }
            }
        }
    }

    private var scanner: some View {
        NavigationStack {
            QRScannerView { code in
                urlText = code
                showScanner = false
            }
            .ignoresSafeArea()
            .navigationTitle("Scan QR code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showScanner = false }
                }
            }
        }
    }

    private func addFromLink() {
        isLoading = true
        errorText = nil
        Task {
            do {
                try await library.addPlaylist(urlString: urlText, name: name)
                dismiss()
            } catch {
                errorText = error.localizedDescription
            }
            isLoading = false
        }
    }
}
