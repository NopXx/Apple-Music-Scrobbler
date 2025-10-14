# Music-Scrobbler

Music-Scrobbler is a macOS app that watches the Apple Music Now Playing feed, normalises track metadata, and sends webhook payloads every time a song starts, updates, or scrobbles. The interface embraces SwiftUI glassmorphism so it blends with macOS Sonoma while surfacing real-time playback status.

## Features
- **Live Apple Music monitor** powered by `DistributedNotificationCenter`.
- **Dynamic artwork matching** with a background gradient that adapts to album colours.
- **Liquid-glass UI** for the menu extra, main window, edit dialog, and settings.
- **Inline track editor** with edit history so corrections persist.
- **Instant webhook payloads** for now playing, paused, and scrobble events.
- **Custom scrobble threshold** (percentage or 4-minute fallback) stored in `UserDefaults`.
- **Menu bar controls** to view details, refresh playback, edit tracks, or quit quickly.

## Requirements
- macOS 13.0 or later (tested on Sonoma)
- Apple Music with notifications enabled
- Xcode 15+ to build from source

## Getting Started
1. Open the project in Xcode.
2. Build and run the `Music-Scrobbler` target.
3. Grant notification permission on first launch so the app can alert you to new tracks.
4. Configure your webhook URL and scrobble threshold from the Settings window.
5. Start Apple Music playback; the menu extra and main window will show the glass UI with live data.

## Webhook Payloads
The app sends JSON payloads with `nowPlaying`, `paused`, and `scrobble` events. Each payload contains:
- Processed artist/title/duration
- Parsed playback position
- A `metadata.trackArtUrl` pointing to cached artwork URLs
- Connector metadata identifying Apple Music as the source

Example `nowPlaying` payload:

```json
{
  "eventName": "nowplaying",
  "time": 1707480065123,
  "data": {
    "song": {
      "processed": {
        "artist": "Radiohead",
        "track": "Subterranean Homesick Alien",
        "duration": 279
      },
      "parsed": {
        "artist": "Radiohead",
        "track": "Subterranean Homesick Alien",
        "duration": 279,
        "currentTime": 102,
        "isPlaying": true
      },
      "flags": {
        "isValid": true
      },
      "metadata": {
        "label": "Apple Music Scrobbler",
        "trackArtUrl": "https://is4-ssl.mzstatic.com/image/thumb/Music/v4/13/72/57/1372570a-19cf-0a62-3d8d-76bbfe2dc93c/source/600x600bb.jpg"
      },
      "connector": {
        "label": "Apple Music"
      }
    }
  }
}
```

## Editing Tracks
Use the “แก้ไขเพลง...” button in the menu or main window to adjust artist or title. The edit history is stored locally and re-applied next time the song plays. Saving edits immediately sends an updated payload without re-fetching artwork.

## Customisation
- Adjust the glass styling or gradients in `Music_ScrobblerApp.swift` and `GlassHelpers.swift`.
- Change scrobble thresholds via Settings or by editing the `scrobblePercent` default key.

## License
MIT
