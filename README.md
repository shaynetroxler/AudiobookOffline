# AudiobookOffline

A native macOS app for [Audiobookshelf](https://github.com/advplyr/audiobookshelf) — browse your library, stream, download books for true offline playback, and keep listening progress synced back to your server.

Built because none of the existing Audiobookshelf clients do local pre-download for offline use; they stream only.

## Features

- Log in to any self-hosted Audiobookshelf server
- Browse your library, search by title or author
- Stream playback, or download a book for fully offline listening (list view and player both have a download control)
- Chapter list with jump-to-chapter
- Variable playback speed
- Spacebar play/pause on the player screen
- Progress reported back to the server as you listen, with local caching so resume position still works with no network connection

## Requirements

- macOS 14+
- An Audiobookshelf server you can reach (local network or otherwise)

## Building

This is a Swift Package Manager project — no Xcode project file needed.

```
swift build
swift run
```

`swift run`/a bare built binary will launch **without a visible window**, because macOS treats an unbundled executable as background-only. To get a normal windowed app, wrap the build output in a minimal `.app` bundle:

```
APP=.build/AudiobookOffline.app
mkdir -p "$APP/Contents/MacOS"
cp .build/arm64-apple-macosx/debug/AudiobookOffline "$APP/Contents/MacOS/AudiobookOffline"
cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>AudiobookOffline</string>
    <key>CFBundleIdentifier</key><string>com.example.audiobookoffline</string>
    <key>CFBundleName</key><string>AudiobookOffline</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
EOF
codesign --force --deep --sign - "$APP"
open "$APP"
```

## Status

Working and in daily use. No open bugs as of this release. If something comes up, it'll land as a point release.

## License

MIT
