import SwiftUI
import AVKit

/// The Cast tab: pick a screen with AirPlay, see what is connected, and get step-by-step help.
struct CastView: View {
    @EnvironmentObject var model: PlayerModel
    @State private var isMirroring = UIScreen.main.isCaptured

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    statusCard
                    pickerCard
                    mirrorCard
                    wiredCard
                    carCard
                }
                .padding()
            }
            .navigationTitle("Cast")
            .onReceive(NotificationCenter.default.publisher(for: UIScreen.capturedDidChangeNotification)) { _ in
                isMirroring = UIScreen.main.isCaptured
            }
            .miniPlayerInset()
        }
    }

    // MARK: - Cards

    private var statusCard: some View {
        let connected = isMirroring || model.externalDisplayConnected
        let text: String
        if isMirroring {
            text = "Your screen is being mirrored or recorded"
        } else if model.externalDisplayConnected {
            text = "Wired display connected"
        } else {
            text = "Not connected to a screen"
        }
        return card {
            Label(text, systemImage: connected ? "checkmark.circle.fill" : "display")
                .font(.headline)
                .foregroundStyle(connected ? Color.green : Color.secondary)
        }
    }

    private var pickerCard: some View {
        card {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Cast a video", systemImage: "airplayvideo")
                        .font(.headline)
                    Text("Start a video, then choose a screen. Apple TVs, AirPlay TVs and AirPlay-capable car screens appear in the list. The video goes straight to the screen in full quality, and your phone stays free.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                AirPlayButton(tint: .systemBlue)
                    .frame(width: 52, height: 52)
            }
        }
    }

    private var mirrorCard: some View {
        card {
            VStack(alignment: .leading, spacing: 6) {
                Label("Mirror your whole iPhone", systemImage: "rectangle.on.rectangle")
                    .font(.headline)
                Text("To show everything on your phone, from any app:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 4) {
                    Text("1. Open Control Center (swipe down from the top-right corner).")
                    Text("2. Tap Screen Mirroring (two overlapping rectangles).")
                    Text("3. Choose your TV or car screen.")
                }
                .font(.subheadline)
                Text("iOS only lets Control Center start whole-screen mirroring. An app can't do it for you.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var wiredCard: some View {
        card {
            VStack(alignment: .leading, spacing: 6) {
                Label("Wired screen", systemImage: "cable.connector")
                    .font(.headline)
                Text("Plug an HDMI adapter into your iPhone and connect it to a monitor or rear-seat screen. Videos you play here show full screen on it, with no phone controls.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var carCard: some View {
        card {
            VStack(alignment: .leading, spacing: 6) {
                Label("In a car", systemImage: "car.fill")
                    .font(.headline)
                Text("Casting works only if your car or its adapter supports AirPlay, or has an HDMI input. Standard CarPlay doesn't let apps show video, so use the screen for passengers, or Car Mode on the phone itself.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

/// The system AirPlay button. Tap it to choose a screen.
struct AirPlayButton: UIViewRepresentable {
    var tint: UIColor = .label

    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.activeTintColor = .systemBlue
        view.tintColor = tint
        view.prioritizesVideoDevices = true
        return view
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        uiView.tintColor = tint
    }
}
