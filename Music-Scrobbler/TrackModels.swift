//
//  TrackModels.swift
//  Music-Scrobbler
//
//  รวบรวมโมเดลและประเภทข้อมูลพื้นฐานที่ใช้ร่วมกันในแอป
//

import Foundation

// Model สำหรับถอดรหัส JSON ที่ได้จาก API
// 1. สร้าง struct สำหรับ object `current_track` ที่ซ้อนอยู่ข้างใน
struct Track: Codable, Equatable, Hashable {
    var trackName: String
    var artistName: String
    let albumName: String?
    let trackArtUrl: URL?
    // Keep original names for edit history mapping
    let originalTrackName: String
    let originalArtistName: String

    private enum CodingKeys: String, CodingKey {
        case trackName = "track_name"
        case artistName = "artist_name"
        case trackArtUrl = "track_art_url"
        case albumName = "album_name"
        case originalTrackName = "original_track_name"
        case originalArtistName = "original_artist_name"
    }
}

// 2. อัปเดต struct หลักให้ตรงกับโครงสร้าง JSON ที่ได้รับ
struct ScrobblerResponse: Decodable {
    let statusMessage: String
    let currentTrack: Track?

    private enum CodingKeys: String, CodingKey {
        case statusMessage = "status_message"
        case currentTrack = "current_track"
    }
}

// Represents the live music info read from AppleScript
struct MusicInfo {
    var trackName: String
    var artistName: String
    var albumName: String
    var durationSeconds: Double
    var positionSeconds: Double
}

// กำหนดประเภทของเหตุการณ์ที่ต้องส่งขึ้น Webhook ให้ชัดเจน
enum ScrobbleEvent: String {
    case nowPlaying = "nowplaying"
    case paused
    case scrobble

    /// เช็กได้ทันทีว่าเหตุการณ์นี้ถือว่าอยู่ในสถานะ playing หรือไม่
    var isPlaying: Bool { self != .paused }
}

// Helper structs for decoding iTunes API response
struct iTunesSearchResult: Decodable {
    let results: [iTunesAlbum]
}

struct iTunesAlbum: Decodable {
    let artworkUrl100: String
}
