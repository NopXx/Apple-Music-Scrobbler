//
//  StatusViewModel.swift
//  Music-Scrobbler
//
//  ViewModel หลักสำหรับประสานข้อมูล Apple Music -> UI -> Webhook
//

import SwiftUI
import Combine
import UserNotifications
import AppKit
import CoreImage

// ViewModel สำหรับจัดการสถานะและตรรกะการดึงข้อมูล
@MainActor // ทำให้ property และ method ทั้งหมดในคลาสนี้ทำงานบน Main Thread โดยอัตโนมัติ
class StatusViewModel: ObservableObject {
    @Published var statusMessage: String = "กำลังโหลด..."
    @Published var trackArtURL: URL?
    @Published var isPlaying: Bool = false
    @Published var dominantBackgroundColor: Color = Color(nsColor: .windowBackgroundColor)
    
    // --- การตั้งค่าที่ดึงมาจาก UserDefaults ---
    private var showNotifications: Bool = true
    private var webhookURL: String = ""
    private var scrobblePercent: Double = 50.0
    private let scrobbleSeconds: Double = 240.0 // 4 นาที

    private enum SettingsKey {
        static let showNotifications = "showNotifications"
        static let webhookURL = "webhookURL"
        static let scrobblePercent = "scrobblePercent"
    }

    private let defaults = UserDefaults.standard
    private var defaultsObserver: NSObjectProtocol?

    // --- ตัวแปรสำหรับจัดการสถานะ Scrobbler ---
    private var timer: Timer?
    private(set) var lastKnownTrack: Track?
    private var currentScrobbleTrackInfo: MusicInfo?
    private var currentTrackSignature: (artist: String, track: String)?
    @Published private(set) var currentPlaybackTime: String = "0:00"
    @Published private(set) var currentTrackDuration: String = "--:--"
    @Published private(set) var playbackProgress: Double = 0
    @Published private(set) var scrobbleStatusText: String = "ยังไม่มีการ Scrobble"
    private var hasBeenScrobbled = false
    private var albumArtCache: [String: URL] = [:]
    private var editHistory = [String: [String: String]]()
    private let editHistoryFileName = "edit_history.json"
    private let nowPlayingMonitor = MusicNowPlayingMonitor()
    private var playbackDisplayTimer: Timer?
    private var playbackLastUpdate: Date?
    private let fallbackBackgroundColor = Color(nsColor: .windowBackgroundColor)

    init() {
        registerDefaultSettings()
        refreshSettings()

        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshSettings()
            }
        }

        loadEditHistory()
        checkMusicStatus()

        // ใช้ Timer เรียกซ้ำทุก 3 วินาที เพื่อให้ตรวจจับการเปลี่ยนเพลงได้ไวขึ้น
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.checkMusicStatus()
        }
    }

    deinit {
        timer?.invalidate()
        playbackDisplayTimer?.invalidate()
        if let defaultsObserver {
            NotificationCenter.default.removeObserver(defaultsObserver)
        }
    }

    // MARK: - Scrobbler Main Logic

    /// อ่านสถานะล่าสุดจาก Apple Music แล้วกระจายไปยังเมธอดย่อยที่เหมาะสม
    func checkMusicStatus() {
        guard let musicInfo = getMusicInfoFromNotifications() else {
            handlePlaybackStopped()
            return
        }

        if shouldHandleAsNewTrack(latest: musicInfo) {
            handleNewTrack(musicInfo)
        } else {
            isPlaying = true
        }

        evaluateScrobble(using: musicInfo)
    }

    /// จัดการกรณีหยุดเล่นให้ส่ง event และรีเซ็ต state ให้สะอาด
    private func handlePlaybackStopped() {
        if let currentInfo = currentScrobbleTrackInfo {
            print("--- เพลงหยุดเล่น ---")
            sendEvent(.paused, with: currentInfo, artUrl: trackArtURL)
        }
        resetState()
    }

    /// ใช้ข้อมูลดิบจาก Apple Music (ก่อน apply edit history) เพื่อตรวจจับเพลงใหม่
    private func shouldHandleAsNewTrack(latest: MusicInfo) -> Bool {
        guard let signature = currentTrackSignature else { return true }
        return signature.track != latest.trackName || signature.artist != latest.artistName
    }

    /// สร้างสถานะใหม่เมื่อพบเพลงใหม่ พร้อมเรียกใช้งาน async task สำหรับรูปปกและ webhook
    private func handleNewTrack(_ musicInfo: MusicInfo) {
        print("\n--- ตรวจพบเพลงใหม่: \(musicInfo.trackName) ---")

        let (finalTrackName, finalArtistName) = applyEditHistory(for: musicInfo)

        currentTrackSignature = (artist: musicInfo.artistName, track: musicInfo.trackName)

        var normalizedInfo = musicInfo
        normalizedInfo.trackName = finalTrackName
        normalizedInfo.artistName = finalArtistName
        currentScrobbleTrackInfo = normalizedInfo
        currentPlaybackTime = formatTime(normalizedInfo.positionSeconds)
        currentTrackDuration = formatTime(normalizedInfo.durationSeconds)
        playbackProgress = progressValue(for: normalizedInfo)
        playbackLastUpdate = Date()
        startPlaybackDisplayTimer()

        hasBeenScrobbled = false
        isPlaying = true
        trackArtURL = nil
        dominantBackgroundColor = fallbackBackgroundColor
        statusMessage = "กำลังเล่น: \(finalTrackName) - \(finalArtistName)"
        updateScrobbleStatus(progress: 0)

        let hadPreviousTrack = lastKnownTrack != nil

        Task { [weak self] in
            guard let self else { return }
            let artUrl = await self.getArtworkURL(artist: finalArtistName, album: musicInfo.albumName)

            await MainActor.run {
                self.trackArtURL = artUrl

                let updatedTrack = Track(
                    trackName: finalTrackName,
                    artistName: finalArtistName,
                    albumName: musicInfo.albumName,
                    trackArtUrl: artUrl,
                    originalTrackName: musicInfo.trackName,
                    originalArtistName: musicInfo.artistName
                )

                if hadPreviousTrack {
                    self.sendNewTrackNotification(for: updatedTrack)
                }

                self.lastKnownTrack = updatedTrack
                self.updateBackgroundColor(with: artUrl)

                if let infoForPayload = self.currentScrobbleTrackInfo {
                    self.sendEvent(.nowPlaying, with: infoForPayload, artUrl: artUrl)
                }
            }
        }
    }

    /// ประเมินว่าถึงเวลา scrobble หรือยัง และอัปเดตข้อความสถานะให้เห็น % ล่าสุด
    private func evaluateScrobble(using musicInfo: MusicInfo) {
        guard var info = currentScrobbleTrackInfo else { return }

        info.durationSeconds = musicInfo.durationSeconds
        info.positionSeconds = musicInfo.positionSeconds
        currentScrobbleTrackInfo = info
        currentPlaybackTime = formatTime(info.positionSeconds)
        currentTrackDuration = formatTime(info.durationSeconds)
        playbackProgress = progressValue(for: info)
        playbackLastUpdate = Date()

        let percent = playbackPercent(for: info, duration: info.durationSeconds)
        updatePlaybackStatus(displayPercent: percent)

        guard !hasBeenScrobbled else { return }

        if shouldScrobble(percent: percent, position: info.positionSeconds) {
            print("--- เงื่อนไข Scrobble สำเร็จ ---")
            hasBeenScrobbled = true
            statusMessage = "Scrobbled: \(displayNames().track)"
            scrobbleStatusText = "Scrobbled แล้ว"

            sendEvent(.scrobble, with: info, artUrl: trackArtURL)
        }
    }

    private func updatePlaybackStatus(displayPercent percent: Double) {
        let names = displayNames()
        guard !names.track.isEmpty else { return }
        statusMessage = "กำลังเล่น: \(names.track) (\(Int(percent))%)"
        updateScrobbleStatus(progress: percent)
    }

    private func updateScrobbleStatus(progress percent: Double) {
        if hasBeenScrobbled {
            scrobbleStatusText = "Scrobbled แล้ว"
            return
        }
        let clamped = max(0, min(100, percent))
        scrobbleStatusText = "รอ Scrobble (\(Int(clamped))%)"
    }

    private func playbackPercent(for latest: MusicInfo, duration: Double) -> Double {
        guard duration > 0 else { return 0 }
        return (latest.positionSeconds / duration) * 100
    }

    private func shouldScrobble(percent: Double, position: Double) -> Bool {
        percent >= scrobblePercent || position >= scrobbleSeconds
    }

    private func displayNames() -> (track: String, artist: String) {
        if let track = lastKnownTrack {
            return (track.trackName, track.artistName)
        }
        if let info = currentScrobbleTrackInfo {
            return (info.trackName, info.artistName)
        }
        return ("", "")
    }
    
    private func resetState() {
        stopPlaybackDisplayTimer()
        currentScrobbleTrackInfo = nil
        currentTrackSignature = nil
        playbackLastUpdate = nil
        hasBeenScrobbled = false
        isPlaying = false
        statusMessage = "หยุดเล่น หรือไม่ได้เปิด Apple Music"
        trackArtURL = nil
        dominantBackgroundColor = fallbackBackgroundColor
        lastKnownTrack = nil
        currentPlaybackTime = "0:00"
        currentTrackDuration = "--:--"
        playbackProgress = 0
        scrobbleStatusText = "ยังไม่มีการ Scrobble"
    }

    // MARK: - Playback Display Timer
    private func startPlaybackDisplayTimer() {
        playbackDisplayTimer?.invalidate()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tickPlaybackDisplay()
        }
        playbackDisplayTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stopPlaybackDisplayTimer() {
        playbackDisplayTimer?.invalidate()
        playbackDisplayTimer = nil
        playbackLastUpdate = nil
    }

    private func tickPlaybackDisplay() {
        guard isPlaying, var info = currentScrobbleTrackInfo else { return }
        let now = Date()
        let last = playbackLastUpdate ?? now
        let delta = now.timeIntervalSince(last)
        guard delta > 0 else { return }
        info.positionSeconds = min(info.durationSeconds, info.positionSeconds + delta)
        playbackLastUpdate = now
        currentScrobbleTrackInfo = info
        currentPlaybackTime = formatTime(info.positionSeconds)
        playbackProgress = progressValue(for: info)
        if !hasBeenScrobbled {
            updatePlaybackStatus(displayPercent: playbackProgress * 100)
        }
    }

    private func progressValue(for info: MusicInfo) -> Double {
        guard info.durationSeconds > 0 else { return 0 }
        let ratio = info.positionSeconds / info.durationSeconds
        return min(max(ratio, 0), 1)
    }

    // MARK: - Now Playing Source
    private func getMusicInfoFromNotifications() -> MusicInfo? {
        if let info = nowPlayingMonitor.currentMusicInfo() {
            #if DEBUG
            print("Now playing (notification): \(info.trackName) - \(info.artistName) @ \(Int(info.positionSeconds))s")
            #endif
            return info
        }

        if nowPlayingMonitor.isCurrentlyPaused() {
            return nil
        }

        return nil
    }

    // MARK: - Network and Data Handling
    private func getArtworkURL(artist: String, album: String) async -> URL? {
        let cacheKey = "\(artist)-\(album)"
        if let cachedUrl = albumArtCache[cacheKey] {
            return cachedUrl
        }
        
        var components = URLComponents(string: "https://itunes.apple.com/search")!
        components.queryItems = [
            URLQueryItem(name: "term", value: "\(artist) \(album)"),
            URLQueryItem(name: "media", value: "music"),
            URLQueryItem(name: "entity", value: "album"),
            URLQueryItem(name: "limit", value: "1")
        ]
        
        guard let url = components.url else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let searchResult = try JSONDecoder().decode(iTunesSearchResult.self, from: data)
            if let firstResult = searchResult.results.first {
                let highResUrlString = firstResult.artworkUrl100.replacingOccurrences(of: "100x100bb.jpg", with: "600x600bb.jpg")
                if let finalUrl = URL(string: highResUrlString) {
                    albumArtCache[cacheKey] = finalUrl
                    return finalUrl
                }
            }
        } catch {
            print("Error fetching or decoding artwork: \(error)")
        }
        return nil
    }
    
    private func sendToWebhook(payload: [String: Any]) {
        guard !webhookURL.isEmpty, let url = URL(string: webhookURL) else {
            if webhookURL.isEmpty { print("Webhook URL is not set.") }
            return
        }

        // Log ข้อมูล payload ที่จะส่งออกเพื่อช่วยดีบัก
        if let jsonData = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted]),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print("ส่ง payload ไปยัง Webhook:\n\(jsonString)")
        } else {
            print("ส่ง payload ไปยัง Webhook: \(payload)")
        }
        
        Task {
            do {
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
                
                let (_, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                    print("Successfully sent to webhook. Status: \(httpResponse.statusCode)")
                } else {
                    print("Failed to send to webhook. Status: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
                }
            } catch {
                print("Error sending to webhook: \(error)")
            }
        }
    }

    private func sendEvent(_ event: ScrobbleEvent, with musicInfo: MusicInfo, artUrl: URL?) {
        let payload = buildWebhookPayload(event: event, musicInfo: musicInfo, artUrl: artUrl)
        sendToWebhook(payload: payload)
    }
    
    private func updateBackgroundColor(with artUrl: URL?) {
        Task.detached { [weak self] in
            let nsColor = await Self.computeDominantColor(from: artUrl) ?? Self.fallbackDominantColor()
            await MainActor.run {
                guard let self else { return }
                withAnimation(.easeInOut(duration: 0.4)) {
                    self.dominantBackgroundColor = Color(nsColor: nsColor)
                }
            }
        }
    }
    
    private static func computeDominantColor(from artUrl: URL?) async -> NSColor? {
        guard let artUrl else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: artUrl)
            guard let image = NSImage(data: data),
                  let averageColor = image.averageColor else { return nil }
            let baseColor = averageColor.usingColorSpace(.deviceRGB) ?? averageColor
            let adjusted = baseColor.blended(withFraction: 0.3, of: .white) ?? baseColor
            return adjusted
        } catch {
            print("Error computing dominant color: \(error.localizedDescription)")
            return nil
        }
    }
    
    nonisolated private static func fallbackDominantColor() -> NSColor {
        .windowBackgroundColor
    }
    
    private func buildWebhookPayload(event: ScrobbleEvent, musicInfo: MusicInfo, artUrl: URL? = nil) -> [String: Any] {
        let payload: [String: Any] = [
            "eventName": event.rawValue,
            "time": Int(Date().timeIntervalSince1970 * 1000),
            "data": [
                "song": [
                    "processed": [
                        "artist": musicInfo.artistName,
                        "track": musicInfo.trackName,
                        "duration": Int(musicInfo.durationSeconds)
                    ],
                    "parsed": [
                        "artist": musicInfo.artistName,
                        "track": musicInfo.trackName,
                        "duration": Int(musicInfo.durationSeconds),
                        "currentTime": Int(musicInfo.positionSeconds),
                        "isPlaying": event.isPlaying
                    ],
                    "flags": ["isValid": true],
                    "metadata": [
                        "label": "Apple Music Scrobbler",
                        "trackArtUrl": artUrl?.absoluteString ?? ""
                    ],
                    "connector": ["label": "Apple Music"]
                ]
            ]
        ]
        return payload
    }
    
    // MARK: - Notification
    private func sendNewTrackNotification(for track: Track) {
        guard showNotifications else { return }

        let content = UNMutableNotificationContent()
        content.title = "กำลังเล่นเพลงใหม่"
        content.subtitle = track.trackName
        content.body = track.artistName
        content.sound = UNNotificationSound.default

        if let artUrl = track.trackArtUrl {
            Task {
                do {
                    let (data, _) = try await URLSession.shared.data(from: artUrl)
                    let fileManager = FileManager.default
                    let temporaryDirectory = fileManager.temporaryDirectory
                    let fileURL = temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("jpg")
                    
                    try data.write(to: fileURL)
                    
                    let attachment = try UNNotificationAttachment(identifier: "albumArt", url: fileURL, options: nil)
                    content.attachments = [attachment]                    
                } catch {
                    print("Could not attach album art to notification: \(error)")
                }
                
                let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
                try? await UNUserNotificationCenter.current().add(request)
            }
        } else {
            Task {
                let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
                try? await UNUserNotificationCenter.current().add(request)
            }
        }
    }
    
    // MARK: - Edit History
    func saveTrackEdit(original: Track, editedArtist: String, editedTrack: String) {
        let originalKey = "\(original.originalArtistName)||||\(original.originalTrackName)"
        editHistory[originalKey] = ["artist": editedArtist, "track": editedTrack]
        saveEditHistoryToFile()
        
        if var currentTrack = self.lastKnownTrack, currentTrack.originalArtistName == original.originalArtistName && currentTrack.originalTrackName == original.originalTrackName {
            currentTrack.artistName = editedArtist
            currentTrack.trackName = editedTrack
            self.lastKnownTrack = currentTrack
            self.statusMessage = "กำลังเล่น: \(editedTrack) - \(editedArtist)"
            if trackArtURL == nil {
                trackArtURL = currentTrack.trackArtUrl
            }
        }

        if var scrobbleInfo = currentScrobbleTrackInfo {
            scrobbleInfo.artistName = editedArtist
            scrobbleInfo.trackName = editedTrack
            currentScrobbleTrackInfo = scrobbleInfo
            updateScrobbleStatus(progress: playbackProgress * 100)
            let eventType: ScrobbleEvent = isPlaying ? .nowPlaying : .paused
            let artUrl = trackArtURL ?? lastKnownTrack?.trackArtUrl
            sendEvent(eventType, with: scrobbleInfo, artUrl: artUrl)
        }
    }
    
    private func registerDefaultSettings() {
        defaults.register(defaults: [
            SettingsKey.showNotifications: true,
            SettingsKey.webhookURL: "",
            SettingsKey.scrobblePercent: 50.0
        ])
    }

    private func refreshSettings() {
        showNotifications = defaults.bool(forKey: SettingsKey.showNotifications)
        webhookURL = defaults.string(forKey: SettingsKey.webhookURL) ?? ""
        if let number = defaults.object(forKey: SettingsKey.scrobblePercent) as? NSNumber {
            scrobblePercent = number.doubleValue
        } else {
            scrobblePercent = 50.0
        }
    }
    
    private func applyEditHistory(for musicInfo: MusicInfo) -> (trackName: String, artistName: String) {
        let originalKey = "\(musicInfo.artistName)||||\(musicInfo.trackName)"
        if let editedData = editHistory[originalKey] {
            let finalTrack = editedData["track", default: musicInfo.trackName]
            let finalArtist = editedData["artist", default: musicInfo.artistName]
            print("พบข้อมูลที่เคยแก้ไข: \(finalTrack) - \(finalArtist)")
            return (finalTrack, finalArtist)
        }
        return (musicInfo.trackName, musicInfo.artistName)
    }
    
    private func getEditHistoryFileURL() -> URL? {
        guard let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let appDirectoryURL = appSupportURL.appendingPathComponent("MusicScrobbler")
        try? FileManager.default.createDirectory(at: appDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        return appDirectoryURL.appendingPathComponent(editHistoryFileName)
    }

    private func loadEditHistory() {
        guard let fileURL = getEditHistoryFileURL(), let data = try? Data(contentsOf: fileURL) else { return }
        if let loadedHistory = try? JSONDecoder().decode([String: [String: String]].self, from: data) {
            self.editHistory = loadedHistory
            print("โหลดประวัติการแก้ไขสำเร็จ")
        }
    }

    private func saveEditHistoryToFile() {
        guard let fileURL = getEditHistoryFileURL() else { return }
        do {
            let data = try JSONEncoder().encode(editHistory)
            try data.write(to: fileURL, options: .atomic)
            print("บันทึกประวัติการแก้ไขสำเร็จ")
        } catch {
            print("ไม่สามารถบันทึกประวัติการแก้ไข: \(error)")
        }
    }

    // MARK: - Formatting Helpers
    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && !seconds.isNaN else { return "0:00" }
        let totalSeconds = max(Int(seconds), 0)
        let minutes = totalSeconds / 60
        let remainder = totalSeconds % 60
        return String(format: "%d:%02d", minutes, remainder)
    }
}

private extension NSImage {
    var averageColor: NSColor? {
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        
        let ciImage = CIImage(cgImage: cgImage)
        let extent = ciImage.extent
        guard let filter = CIFilter(name: "CIAreaAverage") else { return nil }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgRect: extent), forKey: kCIInputExtentKey)
        
        guard let outputImage = filter.outputImage else { return nil }
        
        var bitmap = [UInt8](repeating: 0, count: 4)
        NSImage.averageColorContext.render(
            outputImage,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )
        
        return NSColor(
            calibratedRed: CGFloat(bitmap[0]) / 255.0,
            green: CGFloat(bitmap[1]) / 255.0,
            blue: CGFloat(bitmap[2]) / 255.0,
            alpha: CGFloat(bitmap[3]) / 255.0
        )
    }
    
    private static let averageColorContext = CIContext()
}
