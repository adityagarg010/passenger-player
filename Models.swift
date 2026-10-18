import Foundation

extension String {
    /// The trimmed string, or nil if nothing is left.
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct Channel: Identifiable, Codable, Hashable {
    var id = UUID()
    let name: String
    let url: URL
    let logo: URL?
    let group: String

    /// Stable key for favourites and resume positions.
    /// Local files use the file name, because the app's folder path can change between launches.
    var key: String {
        url.isFileURL ? "file:" + url.lastPathComponent : url.absoluteString
    }
}

struct Playlist: Identifiable, Codable {
    var id = UUID()
    var name: String
    var sourceURL: URL?
    var channels: [Channel]
    var updatedAt: Date

    /// Group names in the order they first appear in the playlist.
    var groups: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for channel in channels where seen.insert(channel.group).inserted {
            result.append(channel.group)
        }
        return result
    }
}

/// Reads M3U / M3U8 playlists (#EXTINF entries with tvg-logo and group-title tags).
enum M3UParser {
    static func parse(_ text: String) -> [Channel] {
        var channels: [Channel] = []
        var name: String?
        var logo: URL?
        var groupTitle: String?
        var extGroup: String?

        let cleaned = text.hasPrefix("\u{FEFF}") ? String(text.dropFirst()) : text

        for rawLine in cleaned.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty { continue }

            if line.hasPrefix("#EXTINF") {
                let info = parseExtInf(line)
                name = info.name
                logo = info.logo
                groupTitle = info.group
                extGroup = nil
            } else if line.hasPrefix("#EXTGRP:") {
                extGroup = String(line.dropFirst(8))
            } else if line.hasPrefix("#") {
                continue
            } else if let url = makeURL(line), url.scheme != nil {
                let channelName = name?.nonEmpty ?? url.lastPathComponent.nonEmpty ?? url.host ?? "Channel"
                let group = groupTitle?.nonEmpty ?? extGroup?.nonEmpty ?? "Ungrouped"
                channels.append(Channel(name: channelName, url: url, logo: logo, group: group))
                name = nil
                logo = nil
                groupTitle = nil
                extGroup = nil
            }
        }
        return channels
    }

    // #EXTINF:-1 tvg-id="x" tvg-logo="http://..." group-title="News",Channel Name
    private static func parseExtInf(_ line: String) -> (name: String, logo: URL?, group: String?) {
        // The channel name follows the first comma that is not inside quotes.
        var inQuotes = false
        var commaIndex: String.Index?
        for index in line.indices {
            let character = line[index]
            if character == "\"" {
                inQuotes.toggle()
            } else if character == "," && !inQuotes {
                commaIndex = index
                break
            }
        }

        var attributePart = line
        var name = ""
        if let commaIndex {
            attributePart = String(line[line.startIndex..<commaIndex])
            name = String(line[line.index(after: commaIndex)...]).trimmingCharacters(in: .whitespaces)
        }

        let attributes = attributes(in: attributePart)
        if name.isEmpty { name = attributes["tvg-name"] ?? "" }
        let logo = attributes["tvg-logo"].flatMap { URL(string: $0) }
        return (name, logo, attributes["group-title"])
    }

    private static let attributeRegex = try! NSRegularExpression(pattern: #"([A-Za-z0-9_\-]+)="([^"]*)""#)

    private static func attributes(in text: String) -> [String: String] {
        var result: [String: String] = [:]
        let nsText = text as NSString
        let matches = attributeRegex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        for match in matches {
            let key = nsText.substring(with: match.range(at: 1)).lowercased()
            result[key] = nsText.substring(with: match.range(at: 2))
        }
        return result
    }

    private static func makeURL(_ string: String) -> URL? {
        if let url = URL(string: string) { return url }
        let allowed = CharacterSet.urlQueryAllowed.union(CharacterSet(charactersIn: "%#[]"))
        guard let encoded = string.addingPercentEncoding(withAllowedCharacters: allowed) else { return nil }
        return URL(string: encoded)
    }
}
