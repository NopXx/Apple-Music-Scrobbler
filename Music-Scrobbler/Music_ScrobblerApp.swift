//
//  Music_ScrobblerApp.swift
//  Music-Scrobbler
//
//  Created by NopXx on 10/10/2568 BE.
//

import SwiftUI
import UserNotifications
import AppKit

@main
struct Music_ScrobblerApp: App {
    // สร้าง StateObject เพื่อจัดการสถานะและข้อมูลจาก API
    // ViewModel จะถูกสร้างขึ้นครั้งเดียวและคงอยู่ตลอดอายุของแอป
    @StateObject private var statusViewModel = StatusViewModel()

    init() {
        // ขออนุญาตผู้ใช้เพื่อส่งการแจ้งเตือนเมื่อแอปเริ่มทำงาน
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
        .defaultSize(width: 520, height: 360)

        // เปลี่ยน systemImage แบบไดนามิกตามสถานะ isPlaying จาก ViewModel
        // "play.circle.fill" สำหรับสถานะกำลังเล่น
        // "stop.circle.fill" สำหรับสถานะหยุดเล่น
        MenuBarExtra ("AppleMusic Scrobbler", systemImage: statusViewModel.isPlaying ? "play.circle.fill" : "stop.circle.fill") {
            // ส่ง ViewModel ไปให้ AppMenu เพื่อใช้งาน
            // Timer จะเริ่มทำงานอัตโนมัติเมื่อ ViewModel ถูกสร้างขึ้น
            AppMenu(viewModel: statusViewModel)
        }
        Settings {
            SettingsView()
        }
        
        // 1. สร้าง Scene ใหม่สำหรับหน้าต่างแก้ไขข้อมูล
        //    Window นี้จะถูกสร้างขึ้นเมื่อมีการร้องขอให้เปิดสำหรับข้อมูลประเภท Track
        WindowGroup("แก้ไขข้อมูลเพลง", for: Track.self) { $track in
            if let trackToEdit = $track.wrappedValue {
                EditTrackView(viewModel: statusViewModel, trackToEdit: trackToEdit)
            }
        }
        .windowLevel(.floating)
        .defaultSize(width: 560, height: 420)
    
    }
}

struct AppMenu: View {
    // รับ ViewModel เข้ามาเพื่อแสดงข้อมูล
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

            if viewModel.isPlaying, let track = viewModel.lastKnownTrack {
                Button("แก้ไขเพลง...") {
                    openWindow(value: track)
                }
                .glassButton()
            }

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

struct EditTrackView: View {
    @ObservedObject var viewModel: StatusViewModel
    let trackToEdit: Track
    @Environment(\.dismiss) private var dismiss // ใช้สำหรับปิดหน้าต่าง

    @State private var editedTrack: String
    @State private var editedArtist: String

    init(viewModel: StatusViewModel, trackToEdit: Track) {
        self.viewModel = viewModel
        self.trackToEdit = trackToEdit
        // ตั้งค่าเริ่มต้นให้กับ State จากข้อมูลเพลงที่ได้รับ
        _editedTrack = State(initialValue: trackToEdit.trackName)
        _editedArtist = State(initialValue: trackToEdit.artistName)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    viewModel.dominantBackgroundColor.opacity(0.92),
                    viewModel.dominantBackgroundColor.opacity(0.55)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            HStack(alignment: .top, spacing: 24) {
                ArtworkView(url: trackToEdit.trackArtUrl, size: 220)
                
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("แก้ไขข้อมูลเพลง")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.white)
                        Text("\(trackToEdit.originalArtistName) • \(trackToEdit.originalTrackName)")
                            .font(.subheadline)
                            .glassSecondaryText()
                            .lineLimit(1)
                    }
                    
                    VStack(alignment: .leading, spacing: 14) {
                        Text("ชื่อเพลง")
                            .font(.footnote)
                            .glassSecondaryText()
                        TextField("ชื่อเพลง", text: $editedTrack)
                            .glassTextFieldBackground()
                        
                        Text("ศิลปิน")
                            .font(.footnote)
                            .glassSecondaryText()
                        TextField("ศิลปิน", text: $editedArtist)
                            .glassTextFieldBackground()
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        Button("ยกเลิก") {
                            dismiss()
                        }
                        .keyboardShortcut(.cancelAction)
                        .glassButton()
                        
                        Button("บันทึก") {
                            viewModel.saveTrackEdit(original: trackToEdit, editedArtist: editedArtist, editedTrack: editedTrack)
                            dismiss()
                        }
                        .keyboardShortcut(.defaultAction)
                        .glassButton()
                    }
                }
            }
            .frame(minHeight: 360, alignment: .top)
            .glassCard(cornerRadius: 24, padding: 24, shadowOpacity: 0.18)
            .padding(24)
        }
        .frame(minWidth: 360, minHeight: 460)
    }
}

struct MainWindowView: View {
    @ObservedObject var viewModel: StatusViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    viewModel.dominantBackgroundColor.opacity(0.9),
                    viewModel.dominantBackgroundColor.opacity(0.6)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.4), value: viewModel.dominantBackgroundColor)
            
            VStack(spacing: 24) {
                HStack(alignment: .top, spacing: 24) {
                    ArtworkView(url: viewModel.trackArtURL)

                    VStack(alignment: .leading, spacing: 14) {
                        if let track = viewModel.lastKnownTrack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(track.trackName)
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .lineLimit(2)
                                    .foregroundStyle(Color.white)
                                Text(track.artistName)
                                    .font(.headline)
                                    .glassSecondaryText()
                                if let album = track.albumName, !album.isEmpty {
                                    Text(album)
                                        .font(.subheadline)
                                        .glassSecondaryText()
                                }
                            }

                            VStack(alignment: .leading, spacing: 8) {
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

                            HStack(spacing: 14) {
                                Button("แก้ไขเพลง...") {
                                    openWindow(value: track)
                                }
                                .keyboardShortcut(.defaultAction)
                                .glassButton()

                                Button("รีเฟรชสถานะ") {
                                    viewModel.checkMusicStatus()
                                }
                                .glassButton()
                            }
                        } else {
                            Text("ยังไม่มีเพลงกำลังเล่น")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.white)
                            Text("เปิด Apple Music แล้วเริ่มเล่นเพลงเพื่อดูรายละเอียดที่นี่")
                                .font(.subheadline)
                                .glassSecondaryText()

                            Button("รีเฟรชสถานะ") {
                                viewModel.checkMusicStatus()
                            }
                            .glassButton()
                        }
                    }
                    Spacer()
                }
                .glassCard()

                HStack {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(viewModel.statusMessage)
                            .glassSecondaryText()
                        Text(viewModel.scrobbleStatusText)
                                    .font(.caption)
                                    .glassSecondaryText()
                    }           
                    Spacer()
                    SettingsLink {
                        Label("ตั้งค่า...", systemImage: "gearshape")
                            .glassControl()
                    }
                    .buttonStyle(.plain)
                    Button {
                        NSApplication.shared.terminate(nil)
                    } label: {
                        Label("ปิดโปรแกรม", systemImage: "power")
                    }
                    .glassButton()
                }
                .glassCard(cornerRadius: 20, padding: 18, shadowOpacity: 0.14)
            }
            .padding(24)
        }
        .frame(minWidth: 520, minHeight: 360)
    }
}

private struct ArtworkView: View {
    let url: URL?
    var size: CGFloat = 200

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)

        ZStack {
            shape
                .fill(.ultraThinMaterial)
                .frame(width: size, height: size)
                .overlay(
                    shape
                        .stroke(Color.white.opacity(0.18), lineWidth: 0.8)
                )
                .shadow(color: Color.black.opacity(0.22), radius: 18, x: 0, y: 12)

            if let url {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    ProgressView()
                }
                .frame(width: size, height: size)
                .clipShape(shape)
                .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 8)
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.white.opacity(0.7))
            }
        }
        .frame(width: size, height: size)
    }
}
