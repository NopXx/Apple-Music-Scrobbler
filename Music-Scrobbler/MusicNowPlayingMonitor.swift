//
//  MusicNowPlayingMonitor.swift
//  Music-Scrobbler
//
//  ตัวช่วยดักฟัง Distributed Notification จาก Apple Music
//

import Foundation

final class MusicNowPlayingMonitor {
    private struct Snapshot {
        var trackName: String
        var artistName: String
        var albumName: String
        var durationSeconds: Double
        var positionSeconds: Double
        var captureDate: Date
        var isPlaying: Bool
    }

    private let queue = DispatchQueue(label: "com.nopxx.music-scrobbler.nowplaying")
    private var snapshot: Snapshot?
    private var observer: NSObjectProtocol?

    init() {
        observer = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.iTunes.playerInfo"),
            object: nil,
            queue: nil
        ) { [weak self] notification in
            self?.handle(notification: notification)
        }
    }

    deinit {
        if let observer {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
    }

    func currentMusicInfo() -> MusicInfo? {
        queue.sync {
            guard let snapshot = snapshot, snapshot.isPlaying else {
                return nil
            }

            let elapsed = Date().timeIntervalSince(snapshot.captureDate)
            let updatedPosition = min(snapshot.durationSeconds, snapshot.positionSeconds + elapsed)

            return MusicInfo(
                trackName: snapshot.trackName,
                artistName: snapshot.artistName,
                albumName: snapshot.albumName,
                durationSeconds: snapshot.durationSeconds,
                positionSeconds: updatedPosition
            )
        }
    }

    func isCurrentlyPaused() -> Bool {
        queue.sync {
            guard let snapshot else { return false }
            return !snapshot.isPlaying
        }
    }

    private func handle(notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        let captureDate = Date()

        queue.async { [weak self] in
            self?.updateSnapshot(with: userInfo, capturedAt: captureDate)
        }
    }

    private func updateSnapshot(with userInfo: [AnyHashable: Any], capturedAt captureDate: Date) {
        let playerState = (userInfo["Player State"] as? String) ?? ""

        let trackName = (userInfo["Name"] as? String) ?? snapshot?.trackName ?? ""
        let artistName = (userInfo["Artist"] as? String) ?? snapshot?.artistName ?? ""
        let albumName = (userInfo["Album"] as? String) ?? snapshot?.albumName ?? ""
        let parsedDuration = Self.parseDuration(userInfo["Total Time"])
        let duration = parsedDuration > 0 ? parsedDuration : (snapshot?.durationSeconds ?? 0)
        let position = Self.parsePosition(userInfo["Player Position"])
        let isPlaying = playerState == "Playing"

        guard !trackName.isEmpty, !artistName.isEmpty else {
            snapshot = nil
            return
        }

        snapshot = Snapshot(
            trackName: trackName,
            artistName: artistName,
            albumName: albumName,
            durationSeconds: duration,
            positionSeconds: position,
            captureDate: captureDate,
            isPlaying: isPlaying
        )

        #if DEBUG
        let stateDescription = isPlaying ? "Playing" : "Paused"
        print("Distributed notification -> \(stateDescription): \(trackName) - \(artistName) @ \(position)s")
        #endif
    }

    private static func parseDuration(_ value: Any?) -> Double {
        if let number = value as? NSNumber {
            let raw = number.doubleValue
            return raw > 1000 ? raw / 1000.0 : raw
        }

        if let string = value as? String, let doubleValue = Double(string) {
            return doubleValue > 1000 ? doubleValue / 1000.0 : doubleValue
        }

        return 0
    }

    private static func parsePosition(_ value: Any?) -> Double {
        if let number = value as? NSNumber {
            return number.doubleValue
        }

        if let string = value as? String, let doubleValue = Double(string) {
            return doubleValue
        }

        return 0
    }
}
