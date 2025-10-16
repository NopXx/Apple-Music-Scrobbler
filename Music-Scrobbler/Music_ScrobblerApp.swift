import SwiftUI
import UserNotifications
import AppKit

@main
struct Music_ScrobblerApp: App {
    @StateObject private var statusViewModel = StatusViewModel()

    init() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification permission granted.")
            } else if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }

    var body: some Scene {
        WindowGroup(id: "mainWindow") {
            MainWindowView(viewModel: statusViewModel)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)

        MenuBarExtra("AppleMusic Scrobbler", systemImage: statusViewModel.isPlaying ? "play.circle.fill" : "stop.circle.fill") {
            AppMenu(viewModel: statusViewModel)
        }
        
        Settings {
            SettingsView()
                .environmentObject(statusViewModel)
        }
        .windowStyle(.hiddenTitleBar)
    }
}

struct AppMenu: View {
    @ObservedObject var viewModel: StatusViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let primaryText = Color.primary.opacity(0.88)
        let secondaryText = Color.primary.opacity(0.72)
        let dividerColor = Color.primary.opacity(0.2)

        VStack(spacing: 14) {
            Text(viewModel.statusMessage)
                .font(.subheadline)
                .foregroundStyle(primaryText)
            
            Text(viewModel.scrobbleStatusText)
                .font(.caption)
                .foregroundStyle(secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Button("แสดงแอป") {
                NSApplication.shared.activate(ignoringOtherApps: true)
            }
            .glassButton()

            Button("รีเฟรชสถานะ") {
                viewModel.checkMusicStatus()
            }
            .glassButton()

            Divider()
                .background(dividerColor)

            SettingsLink {
                Text("ตั้งค่า...")
                    .glassControl()
            }
            .buttonStyle(.plain)
            
            Button("ปิดโปรแกรม") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
            .glassButton()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 18, padding: 18, shadowOpacity: 0.14)
        .padding(8)
    }
}

struct MainWindowView: View {
    @ObservedObject var viewModel: StatusViewModel
    
    @State private var isEditing = false
   @State private var editedTrackName = ""
   @State private var editedArtistName = ""
   @State private var editedAlbumName = ""

    private var primaryTextColor: Color { Color.primary.opacity(0.92) }
    private var secondaryTextColor: Color { Color.primary.opacity(0.78) }
    private var tertiaryTextColor: Color { Color.primary.opacity(0.68) }
    private var captionTextColor: Color { Color.primary.opacity(0.7) }
    private var progressTintColor: Color { Color.primary.opacity(0.6) }
    private var controlsTintColor: Color {
        let base = viewModel.artworkGradient.first ?? Color.primary
        return base.opacity(0.35)
    }

    var body: some View {
        ZStack(alignment: .top) {
            artworkBackground
                .transition(.opacity)
            
            contentLayer
        }
        .frame(width: 420, height: 650) // Fixed size to lock resizing
        .background(Color.black)
        .background(WindowConfigurator())
    }
    
    @ViewBuilder
    private var artworkBackground: some View {
        ZStack(alignment: .top) {
            fallbackGradient
                .ignoresSafeArea()
            
            if let tallVideoUrl = viewModel.trackMasterTallURL {
                LoopingVideoPlayer(videoURL: tallVideoUrl)
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: 420, maxHeight: .infinity, alignment: .top)
            } else if let animationUrl = viewModel.trackAnimationURL {
                LoopingVideoPlayer(videoURL: animationUrl)
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } else if let imageUrl = viewModel.trackArtURL {
                AsyncImage(url: imageUrl) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 420, maxHeight: .infinity, alignment: .top)
                    case .failure, .empty:
                        Color.clear
                    @unknown default:
                        Color.clear
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .clipped()
        .ignoresSafeArea()
        .animation(.spring(), value: viewModel.artworkGradient)
    }
    
    private var backgroundOverlay: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color.black.opacity(0.55),
                Color.black.opacity(0.35),
                Color.black.opacity(0.55)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
    
    @ViewBuilder
    private var contentLayer: some View {
        if viewModel.lastKnownTrack != nil {
            VStack {
                Spacer()
                controlsView
            }
        } else {
            placeholderContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    @ViewBuilder
    private var controlsView: some View {
        let isTallArtwork = viewModel.trackMasterTallURL != nil
        if isTallArtwork {
            VStack(spacing: 15) {
                if let track = viewModel.lastKnownTrack {
                    VStack {
                        if isEditing {
                        VStack(spacing: 10) {
                            TextField("ชื่อเพลง", text: $editedTrackName)
                                .textFieldStyle(PlainTextFieldStyle())
                                .font(.title3.weight(.bold))
                                .foregroundStyle(primaryTextColor)
                                .multilineTextAlignment(.center)
                            TextField("ศิลปิน", text: $editedArtistName)
                                .textFieldStyle(PlainTextFieldStyle())
                                .font(.body)
                                .foregroundStyle(secondaryTextColor)
                                .multilineTextAlignment(.center)
                            TextField("อัลบั้ม", text: $editedAlbumName)
                                .textFieldStyle(PlainTextFieldStyle())
                                .font(.body)
                                .foregroundStyle(tertiaryTextColor)
                                .multilineTextAlignment(.center)
                        }
                    } else {
                            VStack(spacing: 2) {
                            Text(track.trackName)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(primaryTextColor)
                                .multilineTextAlignment(.center)
                            Text(track.artistName)
                                .font(.body)
                                .foregroundStyle(secondaryTextColor)
                            if let album = track.albumName, !album.isEmpty {
                                Text(album)
                                    .font(.callout)
                                    .foregroundStyle(tertiaryTextColor)
                                    .padding(.top, 1)
                            }
                            }
                        }
                    }
                    .padding()
                    
                    VStack(spacing: 5) {
                        ProgressView(value: viewModel.playbackProgress)
                            .progressViewStyle(.linear)
                            .tint(progressTintColor)
                        HStack {
                            Text(viewModel.currentPlaybackTime)
                                .font(.caption2)
                            Spacer()
                            Text(viewModel.currentTrackDuration)
                                .font(.caption2)
                        }
                        .foregroundStyle(captionTextColor)
                    }
                    
                    HStack(spacing: 15) {
                        if isEditing {
                            Button("ยกเลิก") { isEditing = false }.glassButton()
                            Button("บันทึก") {
                                viewModel.saveTrackEdit(original: track, editedArtist: editedArtistName, editedTrack: editedTrackName, editedAlbum: editedAlbumName)
                                isEditing = false
                            }.glassButton()
                        } else {
                            Button(action: {
                                editedTrackName = track.trackName
                                editedArtistName = track.artistName
                                editedAlbumName = track.albumName ?? ""
                                isEditing = true
                            }) { Label("แก้ไข", systemImage: "pencil") }.glassButton()
                            
                            Button(action: { viewModel.checkMusicStatus() }) { Label("รีเฟรช", systemImage: "arrow.clockwise") }.glassButton()
                            
                            SettingsLink { Label("ตั้งค่า", systemImage: "gearshape") }.glassButton()
                        }
                    }
                    .buttonStyle(.plain)

                }
            }
            .padding(12)
            .adaptiveGlassEffect(
                tint: viewModel.artworkGradient.first ?? .clear,
                tintOpacity: 0.35,
                cornerRadius: 0,
                shadowOpacity: 0.08
            )
        } else {
                VStack(spacing: 15) {
                if let track = viewModel.lastKnownTrack {
                    VStack {
                        if isEditing {
                            VStack(spacing: 10) {
                                TextField("ชื่อเพลง", text: $editedTrackName)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(primaryTextColor)
                                    .multilineTextAlignment(.center)
                                TextField("ศิลปิน", text: $editedArtistName)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .font(.body)
                                    .foregroundStyle(secondaryTextColor)
                                    .multilineTextAlignment(.center)
                                TextField("อัลบั้ม", text: $editedAlbumName)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .font(.body)
                                    .foregroundStyle(tertiaryTextColor)
                                    .multilineTextAlignment(.center)
                            }
                        } else {
                            VStack(spacing: 2) {
                                Text(track.trackName)
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(primaryTextColor)
                                    .multilineTextAlignment(.center)
                                Text(track.artistName)
                                    .font(.body)
                                    .foregroundStyle(secondaryTextColor)
                                if let album = track.albumName, !album.isEmpty {
                                    Text(album)
                                        .font(.callout)
                                        .foregroundStyle(tertiaryTextColor)
                                        .padding(.top, 1)
                                }
                            }
                        }
                    }
                    
                    VStack(spacing: 5) {
                        ProgressView(value: viewModel.playbackProgress)
                            .progressViewStyle(.linear)
                            .tint(progressTintColor)
                        HStack {
                            Text(viewModel.currentPlaybackTime)
                                .font(.caption2)
                            Spacer()
                            Text(viewModel.currentTrackDuration)
                                .font(.caption2)
                        }
                        .foregroundStyle(captionTextColor)
                    }
                    
                    HStack(spacing: 15) {
                        if isEditing {
                            Button("ยกเลิก") { isEditing = false }.glassButton()
                            Button("บันทึก") {
                                viewModel.saveTrackEdit(original: track, editedArtist: editedArtistName, editedTrack: editedTrackName, editedAlbum: editedAlbumName)
                                isEditing = false
                            }.glassButton()
                        } else {
                            Button(action: {
                                editedTrackName = track.trackName
                                editedArtistName = track.artistName
                                editedAlbumName = track.albumName ?? ""
                                isEditing = true
                            }) { Label("แก้ไข", systemImage: "pencil") }.glassButton()
                            
                            Button(action: { viewModel.checkMusicStatus() }) { Label("รีเฟรช", systemImage: "arrow.clockwise") }.glassButton()
                            
                            SettingsLink { Label("ตั้งค่า", systemImage: "gearshape") }.glassButton()
                        }
                    }
                    .buttonStyle(.glass)

                }
            }
            .padding(12)
        }
    }
    
    private var placeholderContent: some View {
        VStack {
            Image(systemName: "music.note.list")
                .font(.system(size: 60))
                .foregroundStyle(tertiaryTextColor)
                .padding(.bottom, 10)
            Text("ยังไม่มีเพลงกำลังเล่น")
                .font(.headline)
                .foregroundStyle(primaryTextColor)
        }
    }
    
    private var fallbackGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: viewModel.artworkGradient),
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

private struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            configure(windowFor: view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configure(windowFor: nsView)
        }
    }

    private func configure(windowFor view: NSView) {
        guard let window = view.window else { return }
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.styleMask.insert(.fullSizeContentView)
        window.isMovableByWindowBackground = true
    }
}
