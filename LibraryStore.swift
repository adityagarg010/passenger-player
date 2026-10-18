import Foundation
import SwiftUI

enum LibraryError: LocalizedError {
    case invalidURL
    case badResponse(Int)
    case empty
    case noSource

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "That doesn't look like a valid http or https link."
        case .badResponse(let code): return "The server answered with an error (\(code))."
        case .empty: return "No channels were found in that playlist."
        case .noSource: return "This playlist came from a file, so there is no link to refresh."
        }
    }
}

/// Playlists, favourites and resume positions. Everything is stored on the device.
@MainActor
final class LibraryStore: ObservableObject {
    static let shared = LibraryStore()

    @Published private(set) var playlists: [Playlist] = []
    @Published private(set) var favorites: [Channel] = []

    private var resume: [String: Double]
    private let folder: URL
    private let favoritesFile: URL

    private init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        folder = support.appendingPathComponent("Library", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        favoritesFile = folder.appendingPathComponent("favorites.json")
        resume = UserDefaults.standard.dictionary(forKey: "resumePositions") as? [String: Double] ?? [:]
        load()
    }

    // MARK: - Playlists

    func addPlaylist(urlString: String, name: String?) async throws {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host != nil
        else { throw LibraryError.invalidURL }

        let title = name?.nonEmpty ?? url.host ?? "Playlist"
        let channels = try await Self.fetchChannels(from: url, title: title)
        append(Playlist(name: title, sourceURL: url, channels: channels, updatedAt: Date()))
    }

    func addPlaylist(fileURL: URL) throws {
        let accessing = fileURL.startAccessingSecurityScopedResource()
        defer { if accessing { fileURL.stopAccessingSecurityScopedResource() } }

        let data = try Data(contentsOf: fileURL)
        let title = fileURL.deletingPathExtension().lastPathComponent
        let channels = try Self.channels(from: data, sourceURL: nil, title: title)
        append(Playlist(name: title, sourceURL: nil, channels: channels, updatedAt: Date()))
    }

    func refresh(_ playlist: Playlist) async throws {
        guard let url = playlist.sourceURL else { throw LibraryError.noSource }
        let channels = try await Self.fetchChannels(from: url, title: playlist.name)
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        playlists[index].channels = channels
        playlists[index].updatedAt = Date()
        save(playlists[index])
    }

    func rename(_ id: UUID, to name: String) {
        guard let name = name.nonEmpty,
              let index = playlists.firstIndex(where: { $0.id == id })
        else { return }
        playlists[index].name = name
        save(playlists[index])
    }

    func delete(_ playlist: Playlist) {
        playlists.removeAll { $0.id == playlist.id }
        try? FileManager.default.removeItem(at: fileURL(for: playlist.id))
    }

    // MARK: - Favourites

    func isFavorite(_ channel: Channel) -> Bool {
        favorites.contains { $0.key == channel.key }
    }

    func toggleFavorite(_ channel: Channel) {
        if let index = favorites.firstIndex(where: { $0.key == channel.key }) {
            favorites.remove(at: index)
        } else {
            favorites.append(channel)
        }
        let list = favorites
        let file = favoritesFile
        Task.detached(priority: .utility) {
            if let data = try? JSONEncoder().encode(list) {
                try? data.write(to: file, options: .atomic)
            }
        }
    }

    // MARK: - Resume positions

    func resumeTime(for key: String) -> Double? {
        resume[key]
    }

    func setResume(_ seconds: Double?, for key: String) {
        if let seconds {
            resume[key] = seconds
        } else {
            resume.removeValue(forKey: key)
        }
        UserDefaults.standard.set(resume, forKey: "resumePositions")
    }

    // MARK: - Storage

    private func append(_ playlist: Playlist) {
        playlists.append(playlist)
        playlists.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        save(playlist)
    }

    private func fileURL(for id: UUID) -> URL {
        folder.appendingPathComponent("playlist-\(id.uuidString).json")
    }

    private func save(_ playlist: Playlist) {
        let file = fileURL(for: playlist.id)
        Task.detached(priority: .utility) {
            if let data = try? JSONEncoder().encode(playlist) {
                try? data.write(to: file, options: .atomic)
            }
        }
    }

    private func load() {
        let decoder = JSONDecoder()
        if let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) {
            playlists = files
                .filter { $0.lastPathComponent.hasPrefix("playlist-") && $0.pathExtension == "json" }
                .compactMap { try? Data(contentsOf: $0) }
                .compactMap { try? decoder.decode(Playlist.self, from: $0) }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
        if let data = try? Data(contentsOf: favoritesFile),
           let list = try? decoder.decode([Channel].self, from: data) {
            favorites = list
        }
    }

    // MARK: - Loading (runs off the main thread)

    nonisolated private static func fetchChannels(from url: URL, title: String) async throws -> [Channel] {
        var request = URLRequest(url: url)
        request.timeoutInterval = 60
        request.setValue("PassengerPlayer/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw LibraryError.badResponse(http.statusCode)
        }
        return try channels(from: data, sourceURL: url, title: title)
    }

    nonisolated static func channels(from data: Data, sourceURL: URL?, title: String) throws -> [Channel] {
        let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) ?? ""

        // A link that points straight at one HLS stream, not at a list of channels.
        if let sourceURL,
           text.contains("#EXT-X-TARGETDURATION") || text.contains("#EXT-X-STREAM-INF") {
            return [Channel(name: title, url: sourceURL, logo: nil, group: "Streams")]
        }

        let channels = M3UParser.parse(text)
        guard !channels.isEmpty else { throw LibraryError.empty }
        return channels
    }
}
