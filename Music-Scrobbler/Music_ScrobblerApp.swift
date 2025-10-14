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
        VStack(spacing: 14) {
            Text(viewModel.statusMessage)
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.85))
            
            Text(viewModel.scrobbleStatusText)
                .font(.caption)
                .foregroundStyle(Color.white.opacity(0.75))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if viewModel.lastKnownTrack != nil {
                VStack(spacing: 6) {
                    ProgressView(value: viewModel.playbackProgress)
                        .progressViewStyle(.linear)
                        .tint(Color.white.opacity(0.85))
                    HStack {
                        Text(viewModel.currentPlaybackTime)
                            .monospacedDigit()
                            .glassSecondaryText()
                        Spacer()
                        Text(viewModel.currentTrackDuration)
                            .monospacedDigit()
                            .glassSecondaryText()
                    }
                    .font(.caption)
                }
            }
            
            Button("แสดง Music Now Playing") {
                NSApplication.shared.activate(ignoringOtherApps: true)
                openWindow(id: "mainWindow")
            }
            .glassButton()

            Button("รีเฟรชสถานะ") {
                viewModel.checkMusicStatus()
            }
            .glassButton()

            Divider()
                .background(Color.white.opacity(0.2))

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

    private let artworkHeightRatio = 0.65

    var body: some View {
        ZStack {
            // This gradient acts as the base background for the whole window,
            // especially for the 'no track' state.
            LinearGradient(
                gradient: Gradient(colors: viewModel.artworkGradient),
                startPoint: .top,
                endPoint: .bottom
            )
            .animation(.spring(), value: viewModel.artworkGradient)
            .ignoresSafeArea()

            if viewModel.lastKnownTrack != nil {
                // Split view layout when a track is playing
                GeometryReader { geometry in
                    VStack(spacing: 0) {
                        artworkView(height: geometry.size.height * artworkHeightRatio)
                        controlsView(height: geometry.size.height * (1 - artworkHeightRatio))
                    }
                }
            } else {
                // Placeholder content when no track is playing
                placeholderContent
            }
        }
        .frame(width: 420, height: 650) // Fixed size to lock resizing
        .background(Color.black)
    }
    
    @ViewBuilder
    private func artworkView(height: CGFloat) -> some View {
        ZStack {
            // Fallback color in case of loading errors
            Color.gray.opacity(0.2)

            if let animationUrl = viewModel.trackAnimationURL {
                LoopingVideoPlayer(videoURL: animationUrl)
                    .aspectRatio(contentMode: .fill)
            } else if let imageUrl = viewModel.trackArtURL {
                AsyncImage(url: imageUrl) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        // Shows the gray fallback during load/error
                        Color.clear
                    }
                }
            }
        }
        .frame(height: height)
        .clipped()
    }
    
    @ViewBuilder
    private func controlsView(height: CGFloat) -> some View {
        // The ZStack for the controls area no longer needs its own background,
        // as the main ZStack in `body` provides it.
        VStack(spacing: 15) {
            if let track = viewModel.lastKnownTrack {
                VStack {
                    if isEditing {
                        VStack(spacing: 10) {
                            TextField("ชื่อเพลง", text: $editedTrackName)
                                .textFieldStyle(PlainTextFieldStyle())
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                            TextField("ศิลปิน", text: $editedArtistName)
                                .textFieldStyle(PlainTextFieldStyle())
                                .font(.body)
                                .foregroundStyle(Color.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                            TextField("อัลบั้ม", text: $editedAlbumName)
                                .textFieldStyle(PlainTextFieldStyle())
                                .font(.body)
                                .foregroundStyle(Color.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                    } else {
                        VStack(spacing: 2) {
                            Text(track.trackName)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                            Text(track.artistName)
                                .font(.body)
                                .foregroundStyle(Color.white.opacity(0.8))
                            if let album = track.albumName, !album.isEmpty {
                                Text(album)
                                    .font(.callout)
                                    .foregroundStyle(Color.white.opacity(0.7))
                                    .padding(.top, 1)
                            }
                        }
                    }
                }
                .padding(.top, 20)
                
                VStack(spacing: 5) {
                    ProgressView(value: viewModel.playbackProgress)
                        .progressViewStyle(.linear)
                        .tint(Color.white.opacity(0.7))
                    HStack {
                        Text(viewModel.currentPlaybackTime).font(.caption2)
                        Spacer()
                        Text(viewModel.currentTrackDuration).font(.caption2)
                    }
                    .foregroundStyle(Color.white.opacity(0.7))
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
        .padding(.horizontal, 30)
        .frame(height: height)
    }
    
    private var placeholderContent: some View {
        VStack {
            Image(systemName: "music.note.list")
                .font(.system(size: 60))
                .foregroundStyle(Color.white.opacity(0.7))
                .padding(.bottom, 10)
            Text("ยังไม่มีเพลงกำลังเล่น")
                .font(.headline)
                .foregroundStyle(Color.white.opacity(0.8))
        }
    }
}