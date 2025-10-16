//
//  MusicNowPlayingMonitor.swift
//  Music-Scrobbler
//
//  ตัวช่วยดักฟัง Distributed Notification จาก Apple Music
//

import Foundation
import AppKit

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
        let previousSnapshot = snapshot

        let trackName = (userInfo["Name"] as? String) ?? snapshot?.trackName ?? ""
        let artistName = (userInfo["Artist"] as? String) ?? snapshot?.artistName ?? ""
        let albumName = (userInfo["Album"] as? String) ?? snapshot?.albumName ?? ""
        let parsedDuration = Self.parseDuration(userInfo["Total Time"])
        var duration = parsedDuration > 0 ? parsedDuration : (snapshot?.durationSeconds ?? 0)
        var position = Self.parsePosition(userInfo["Player Position"])
        var isPlaying = playerState == "Playing"

        let isSameTrack = {
            guard let previousSnapshot else { return false }
            return previousSnapshot.trackName == trackName &&
            previousSnapshot.artistName == artistName &&
            previousSnapshot.albumName == albumName &&
            abs(previousSnapshot.durationSeconds - duration) < 1.0
        }()

        if let previousSnapshot, isSameTrack {
            let timeSinceLast = captureDate.timeIntervalSince(previousSnapshot.captureDate)
            let previousPosition = previousSnapshot.positionSeconds
            let expectedProgress = duration > 0
                ? min(previousPosition + max(timeSinceLast, 0), duration)
                : previousPosition + max(timeSinceLast, 0)

            if position <= 1.0 && previousSnapshot.positionSeconds > 1.0 {
                if let preciseState = fetchPreciseStateFromAppleMusic() {
                    if preciseState.position > 0 {
                        position = preciseState.position
                    }
                    if preciseState.duration > 0 {
                        duration = preciseState.duration
                    }
                    switch preciseState.state {
                    case "playing":
                        isPlaying = true
                    case "paused":
                        isPlaying = false
                    default:
                        break
                    }
                } else {
                    position = max(position, previousSnapshot.positionSeconds)
                }
            }

            if position <= 1.0 {
                if previousSnapshot.isPlaying && isPlaying && timeSinceLast < 2 {
                    position = max(position, expectedProgress)
                } else if previousSnapshot.isPlaying && !isPlaying {
                    position = max(position, expectedProgress)
                } else if !previousSnapshot.isPlaying && isPlaying {
                    position = max(position, expectedProgress)
                } else if !previousSnapshot.isPlaying && !isPlaying {
                    position = max(position, previousPosition)
                }
            } else if position + 0.5 < previousPosition && timeSinceLast < 2 {
                position = max(position, expectedProgress)
            }
        }

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

    private func fetchPreciseStateFromAppleMusic() -> (state: String, position: Double, duration: Double)? {
        let scriptSource = """
        tell application "Music"
            if it is running then
                set playerState to player state as string
                if playerState is "stopped" then
                    return {"stopped", 0, 0}
                end if
                try
                    set playerPosition to player position
                    set trackDuration to duration of current track
                    return {playerState, playerPosition, trackDuration}
                on error
                    return {"error", 0, 0}
                end try
            else
                return {"stopped", 0, 0}
            end if
        end tell
        """

        guard let script = NSAppleScript(source: scriptSource) else { return nil }
        var errorDict: NSDictionary?
        let result = script.executeAndReturnError(&errorDict)
        if errorDict != nil {
            return nil
        }

        guard result.numberOfItems == 3,
              let state = result.atIndex(1)?.stringValue else {
            return nil
        }

        let position = result.atIndex(2)?.doubleValue ?? 0
        let duration = result.atIndex(3)?.doubleValue ?? 0
        #if DEBUG
        print("AppleScript precise state -> \(state.lowercased()) @ \(position)s / \(duration)s")
        #endif
        print("AppleScript precise state -> \(state.lowercased()) @ \(position)s / \(duration)s")
        return (state.lowercased(), position, duration)
    }
}
