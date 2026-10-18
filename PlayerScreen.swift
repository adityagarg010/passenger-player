import SwiftUI
import AVKit

/// Full-screen player. Has a normal layout and a landscape "car mode" with large controls.
struct PlayerScreen: View {
    @EnvironmentObject var model: PlayerModel
    @EnvironmentObject var library: LibraryStore
    @State private var carMode = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if carMode {
                CarModeView(carMode: $carMode)
            } else {
                standardLayout
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(carMode)
    }

    private var standardLayout: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Button { model.showFullPlayer = false } label: {
                    Image(systemName: "chevron.down")
                }
                Text(model.current?.name ?? "")
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                if let current = model.current {
                    Button { library.toggleFavorite(current) } label: {
                        Image(systemName: library.isFavorite(current) ? "star.fill" : "star")
                    }
                }
                Button { carMode = true } label: {
                    Image(systemName: "car.fill")
                }
                AirPlayButton(tint: .white)
                    .frame(width: 32, height: 32)
            }
            .font(.title3)
            .foregroundStyle(.white)
            .padding(.horizontal)
            .padding(.vertical, 10)

            ZStack {
                SystemPlayerView(player: model.player)
                if let message = model.errorMessage {
                    ErrorOverlay(message: message)
                }
            }

            if model.hasQueue {
                HStack(spacing: 40) {
                    Button { model.previous() } label: { Image(systemName: "backward.end.fill") }
                        .disabled(!model.canGoPrevious)
                    Button { model.next() } label: { Image(systemName: "forward.end.fill") }
                        .disabled(!model.canGoNext)
                }
                .font(.title)
                .foregroundStyle(.white)
                .padding(.vertical, 12)
            }
        }
    }
}

/// Landscape layout for a passenger using the phone in a dashboard mount. Big touch targets.
struct CarModeView: View {
    @Binding var carMode: Bool
    @EnvironmentObject var model: PlayerModel
    @EnvironmentObject var library: LibraryStore
    @State private var showControls = true

    var body: some View {
        ZStack {
            PlayerLayerView(player: model.player)
                .ignoresSafeArea()

            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { withAnimation { showControls.toggle() } }

            if showControls {
                controls.transition(.opacity)
            }
            if let message = model.errorMessage {
                ErrorOverlay(message: message)
            }
        }
        .onAppear { OrientationController.request(.landscape) }
        .onDisappear { OrientationController.request(.allButUpsideDown) }
    }

    private var controls: some View {
        VStack {
            HStack(alignment: .center, spacing: 12) {
                bigButton("xmark", size: 28) { carMode = false }
                Text(model.current?.name ?? "")
                    .font(.title2.bold())
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let current = model.current {
                    bigButton(library.isFavorite(current) ? "star.fill" : "star", size: 28) {
                        library.toggleFavorite(current)
                    }
                }
                AirPlayButton(tint: .white)
                    .frame(width: 52, height: 52)
            }

            Spacer()

            HStack(spacing: 36) {
                bigButton("backward.end.fill", size: 36) { model.previous() }
                    .disabled(!model.canGoPrevious)
                bigButton("gobackward.10", size: 36) { model.seek(by: -10) }
                bigButton(model.isPlaying ? "pause.circle.fill" : "play.circle.fill", size: 72) {
                    model.togglePlayPause()
                }
                bigButton("goforward.10", size: 36) { model.seek(by: 10) }
                bigButton("forward.end.fill", size: 36) { model.next() }
                    .disabled(!model.canGoNext)
            }
        }
        .padding(24)
        .foregroundStyle(.white)
        .background(
            LinearGradient(
                colors: [.black.opacity(0.65), .clear, .black.opacity(0.65)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    private func bigButton(_ symbol: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size))
                .frame(minWidth: 56, minHeight: 56)
        }
    }
}

struct ErrorOverlay: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding()
            .background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 12))
            .padding()
    }
}

enum OrientationController {
    static func request(_ mask: UIInterfaceOrientationMask) {
        // Skip the external display scene; only the phone's own window can rotate.
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.session.role == .windowApplication }
        scene?.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { error in
            print("Orientation change failed: \(error)")
        }
    }
}

// MARK: - Player views

/// Standard system player with its own controls, subtitles menu, AirPlay and Picture in Picture.
struct SystemPlayerView: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.allowsPictureInPicturePlayback = true
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        controller.videoGravity = .resizeAspect
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}
}

/// Bare video surface with no controls (mini player and car mode).
final class PlayerLayerUIView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerLayerUIView {
        let view = PlayerLayerUIView()
        view.backgroundColor = .black
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspect
        return view
    }

    func updateUIView(_ uiView: PlayerLayerUIView, context: Context) {}
}
