import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// Folder inside the app where imported videos are kept, so they play offline.
enum VideoFolder {
    static let url: URL = {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let folder = documents.appendingPathComponent("Videos", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }()

    static func uniqueDestination(for filename: String) -> URL {
        var destination = url.appendingPathComponent(filename)
        let base = destination.deletingPathExtension().lastPathComponent
        let ext = destination.pathExtension
        var counter = 1
        while FileManager.default.fileExists(atPath: destination.path) {
            let newName = ext.isEmpty ? "\(base) \(counter)" : "\(base) \(counter).\(ext)"
            destination = url.appendingPathComponent(newName)
            counter += 1
        }
        return destination
    }
}

/// Copies a picked video out of the photo library into the app's video folder.
struct PickedMovie: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let ext = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            let destination = VideoFolder.uniqueDestination(for: "Video-\(Int(Date().timeIntervalSince1970)).\(ext)")
            try FileManager.default.copyItem(at: received.file, to: destination)
            return PickedMovie(url: destination)
        }
    }
}

@MainActor
final class LocalLibrary: ObservableObject {
    static let shared = LocalLibrary()

    @Published private(set) var videos: [Channel] = []
    @Published var isImporting = false
    @Published var errorMessage: String?

    private static let extensions: Set<String> = ["mp4", "m4v", "mov", "mkv", "avi", "ts", "webm"]

    private init() {
        reload()
    }

    func reload() {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: VideoFolder.url,
            includingPropertiesForKeys: [.contentModificationDateKey]
        )) ?? []

        videos = files
            .filter { Self.extensions.contains($0.pathExtension.lowercased()) }
            .sorted { modified($0) > modified($1) }
            .map { Channel(name: $0.deletingPathExtension().lastPathComponent, url: $0, logo: nil, group: "Local") }
    }

    func importPhoto(_ item: PhotosPickerItem) async {
        isImporting = true
        do {
            _ = try await item.loadTransferable(type: PickedMovie.self)
        } catch {
            errorMessage = error.localizedDescription
        }
        isImporting = false
        reload()
    }

    func importFile(at url: URL) {
        isImporting = true
        Task.detached(priority: .userInitiated) {
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }

            let failure: String?
            do {
                try FileManager.default.copyItem(at: url, to: VideoFolder.uniqueDestination(for: url.lastPathComponent))
                failure = nil
            } catch {
                failure = error.localizedDescription
            }

            await MainActor.run {
                let library = LocalLibrary.shared
                library.isImporting = false
                library.errorMessage = failure
                library.reload()
            }
        }
    }

    func delete(at offsets: IndexSet) {
        for index in offsets {
            try? FileManager.default.removeItem(at: videos[index].url)
        }
        reload()
    }

    private func modified(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }
}

struct LocalView: View {
    @EnvironmentObject var local: LocalLibrary
    @EnvironmentObject var model: PlayerModel

    @State private var pickerItem: PhotosPickerItem?
    @State private var showImporter = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    PhotosPicker(selection: $pickerItem, matching: .videos) {
                        Label("Import from Photos", systemImage: "photo.on.rectangle")
                    }
                    Button {
                        showImporter = true
                    } label: {
                        Label("Import from Files", systemImage: "folder.badge.plus")
                    }
                    if local.isImporting {
                        HStack {
                            ProgressView()
                            Text("Importing…")
                        }
                    }
                } footer: {
                    Text("Imported videos are stored in the app, so they play offline.")
                }

                if !local.videos.isEmpty {
                    Section("Videos") {
                        ForEach(local.videos, id: \.key) { video in
                            Button {
                                model.open(video, in: local.videos)
                            } label: {
                                Label(video.name, systemImage: "film")
                                    .foregroundStyle(.primary)
                            }
                        }
                        .onDelete { local.delete(at: $0) }
                    }
                }
            }
            .navigationTitle("Local")
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                Task {
                    await local.importPhoto(item)
                    pickerItem = nil
                }
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.movie, .data],
                allowsMultipleSelection: true
            ) { result in
                if case .success(let urls) = result {
                    urls.forEach { local.importFile(at: $0) }
                }
            }
            .alert(
                "Import failed",
                isPresented: Binding(
                    get: { local.errorMessage != nil },
                    set: { if !$0 { local.errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(local.errorMessage ?? "")
            }
            .miniPlayerInset()
        }
    }
}
