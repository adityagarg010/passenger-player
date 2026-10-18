# Passenger Player: build and install without a Mac

You only need a Windows laptop, an iPhone, and free accounts. GitHub's cloud Macs compile the app, and a Windows tool installs it on your iPhone.

Limits of the free route: the app expires after 7 days and must be reinstalled (takes a minute), you can have 3 sideloaded apps at a time, and there is no TestFlight. TestFlight needs the paid Apple Developer account. Every feature works either way.

## 1. Put the project on GitHub (once)

1. Create a free account at github.com.
2. Click **New repository**. Name it `passenger-player`. Choose **Private** (free, with about 200 Mac build minutes a month, enough for roughly 20 builds) or **Public** (unlimited builds, but anyone can see the code).
3. On the empty repo page click **uploading an existing file**.
4. Unzip this project on your laptop, open the folder, select everything inside it (`PassengerPlayer`, `docs`, `.github`, `project.yml`, `README.md`) and drag it all into the browser. Click **Commit changes**.
5. Check that `.github/workflows/build.yml` appears in the file list. If the `.github` folder is missing, click **Add file > Create new file**, type `.github/workflows/build.yml` as the name, and paste in the contents of that file.

## 2. Build the app

1. Open the **Actions** tab. The build **Build IPA** starts by itself and takes about 5 to 10 minutes.
2. When it shows a green tick, open the run and download **PassengerPlayer-ipa** from the Artifacts section at the bottom. Unzip it to get `PassengerPlayer.ipa`.
3. If it shows a red cross, open the run, open the **Show errors** step, and paste the lines here. I'll fix the code, and you upload the new file to GitHub and the build runs again.

To rebuild later without changing anything: Actions > Build IPA > **Run workflow**.

## 3. Install on your iPhone from Windows

1. Install **iTunes** and **iCloud** from Apple's website (apple.com). Do not use the Microsoft Store versions.
2. Install **Sideloadly** from sideloadly.io.
3. Connect the iPhone by USB and tap **Trust** on the phone.
4. Open Sideloadly, drag `PassengerPlayer.ipa` in, type your Apple ID, and click **Start**. Using a spare Apple ID is a good idea.
5. On the iPhone: Settings > General > VPN & Device Management > tap your Apple ID > **Trust**.
6. Settings > Privacy & Security > **Developer Mode** > turn on and restart. This option only appears after the first sideload.
7. Open Passenger Player.

## 4. Every 7 days

Plug in the phone and click **Start** in Sideloadly again with the same IPA. It renews the app and keeps your playlists and favourites. Sideloadly can also refresh automatically while the laptop is on the same Wi-Fi.

## What the app does

Playlists (M3U link, QR code or file), channels with groups, search and favourites, a player with subtitles, AirPlay, Picture in Picture and resume, Car Mode, a mini player, offline local videos, and a Cast tab with AirPlay, Control Center mirroring steps and wired HDMI display support. It ships with no content. Users add their own playlists.

`docs/MAC-XCODE.md` has the older notes for building on a Mac, if you ever get one.
