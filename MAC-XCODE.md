# Passenger Player

An iPhone/iPad app that plays video from your own playlists and files and sends it to a second screen. It is a player only: it ships with no channels or content, and users add their own.

Requires iOS 17+ and Xcode 15+. Written for SwiftUI, with no third-party packages.

## Features

- **Playlists:** add an M3U/M3U8 link, scan a QR code, paste, or pick a file. Refresh, rename and delete. A link that points straight at one HLS stream also works.
- **Channels:** logos, group filter, search, favourites.
- **Player:** HLS and HTTP streams, system controls with embedded subtitles, AirPlay, Picture in Picture, background audio, lock screen controls, resume position for films and episodes.
- **Car Mode:** landscape layout with large controls (previous/next channel, play/pause, 10 second skip, favourite, AirPlay).
- **Mini player:** keeps playing, with a small video thumbnail, while you browse.
- **Local videos:** import from Photos or Files into the app, play offline.
- **Cast tab:** AirPlay screen picker, connection status, Control Center mirroring steps, and wired HDMI/USB-C display support (full-screen video on the external screen).

## Not included yet

Jellyfin/Emby/Plex browsing, Xtream login, MKV/HEVC/DTS software decoding (iOS can't play MKV natively), external subtitle files (.srt), subscriptions.

## Files

| File | What it does |
| --- | --- |
| `PassengerPlayerApp.swift` | App entry, orientation, external display routing |
| `Models.swift` | `Channel`, `Playlist`, M3U parser |
| `LibraryStore.swift` | Saved playlists, favourites, resume positions |
| `PlayerModel.swift` | Shared `AVPlayer`, queue, errors, lock screen controls |
| `ContentView.swift` | Tabs and mini player |
| `PlaylistsView.swift` | Playlist list and Add playlist screen |
| `ChannelListView.swift` | Channels, favourites tab, channel row |
| `PlayerScreen.swift` | Full player, Car Mode, video views |
| `LocalView.swift` | Offline video library |
| `CastView.swift` | Cast tab and AirPlay button |
| `QRScannerView.swift` | Camera QR reader |
| `ExternalSceneDelegate.swift` | Wired external display |

## Set up in Xcode

1. File > New > Project > iOS > App. Interface: SwiftUI, Language: Swift. Name it, for example, `PassengerPlayer`.
2. Delete the generated `ContentView.swift` and app file, then drag in all the `.swift` files from this folder. Set the minimum deployment target to iOS 17.
3. Signing & Capabilities: choose your team and a unique Bundle Identifier. Add **Background Modes** and tick **Audio, AirPlay, and Picture in Picture**.
4. Add these keys to the target's Info (Target > Info tab, or right-click `Info.plist` > Open As > Source Code if you have one):

```xml
<key>NSCameraUsageDescription</key>
<string>Used to scan a QR code that contains your playlist link.</string>

<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>

<key>UIApplicationSceneManifest</key>
<dict>
    <key>UIApplicationSupportsMultipleScenes</key>
    <false/>
    <key>UISceneConfigurations</key>
    <dict>
        <key>UIWindowSceneSessionRoleExternalDisplayNonInteractive</key>
        <array>
            <dict>
                <key>UISceneConfigurationName</key>
                <string>External Display</string>
                <key>UISceneDelegateClassName</key>
                <string>$(PRODUCT_MODULE_NAME).ExternalSceneDelegate</string>
            </dict>
        </array>
    </dict>
</dict>
```

   If Xcode already created an `UIApplicationSceneManifest`, add the `UISceneConfigurations` part inside it instead of a second copy.

   The ATS setting is needed because many playlist servers use plain `http`. In App Store Connect, explain that the app plays user-supplied playlists and streams.
5. Make sure the iPhone orientations in the target's General tab include both landscape modes (Car Mode needs them).
6. Build to a real iPhone. AirPlay, external displays and the camera don't work in the Simulator.

## Test

- Add a playlist link you have the right to use, tap a channel, try favourites, search and the group filter.
- Tap the car icon in the player for Car Mode.
- Cast tab: tap the AirPlay button and pick a screen, or use Control Center > Screen Mirroring.
- Wired: connect an HDMI adapter to a monitor and play a video.

## Upload to TestFlight

1. Join the Apple Developer Program (developer.apple.com/programs, paid annual fee).
2. App Store Connect > Apps > **+** > New App, with the same Bundle ID as Xcode.
3. In Xcode choose **Any iOS Device (arm64)**, then Product > **Archive**.
4. Organizer > select the archive > **Distribute App** > **App Store Connect** > Upload.
5. Wait for processing (10 to 30 minutes) and answer any export compliance question.
6. App Store Connect > your app > **TestFlight**:
   - **Internal Testing:** up to 100 people from your team, no review.
   - **External Testing:** add testers by email or public link. The first build goes through Beta App Review, usually within a day.
7. Testers install the TestFlight app and accept the invite. Builds expire after 90 days.

## Before submitting

- Use your own app name, icon, screenshots and description. Don't copy another app's branding.
- The listing and in-app text must not offer or hint at free TV, sports or channels. Say the app plays playlists you provide.
- Don't bundle or link to any playlists.
- DRM-protected content goes black on external screens. That's an Apple restriction.
