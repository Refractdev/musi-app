# Musi App

Native SwiftUI music discovery and local library app targeting iOS 17.

## Open and run

Open `MusiApp.xcodeproj` in Xcode 26 or newer on macOS, select the `MusiApp` scheme, choose an iOS 17 or newer simulator, and run. The project uses the iOS 26 Liquid Glass API behind an availability check, so an SDK that includes iOS 26 is required to compile it. Signing is configured automatically for a personal device build; choose your Apple development team in Xcode if installing on an iPhone.

The project has no third-party package dependencies. The `MusiAppTests` target contains provider, persistence, deduplication, and queue tests.

## Music sources and audit notes

### iTunes Search API

The app uses `https://itunes.apple.com/search` with `term`, `entity=song`, `limit`, and the selected country code (initialized from the device region). Search uses URL components, keeps a five-minute in-memory metadata cache, and spaces outbound requests to stay below Apple’s documented approximate 20 calls per minute. Items with a valid HTTPS `previewUrl` and a store link are marked **Preview**; items without both are metadata only. A preview is never represented as a full track and is not saved to the library or queue. iTunes promotional previews are streamed, not downloaded; the Now Playing screen shows the courtesy attribution and the Apple-provided Listen on Apple Music badge linked to the store item. Badge artwork is from [Apple Music Identity Guidelines](https://marketing.services.apple/apple-music-identity-guidelines).

On 2026-10-27, a live request for `daft punk`, `entity=song`, `limit=3`, `country=us` returned HTTP 200, `resultCount=3`, and fields including track/collection IDs, title, artist, album, artwork, duration, preview URL, store URL, and `isStreamable`. A 1 KB range request to the returned preview produced HTTP 206 and `Content-Type: audio/x-m4p`. This confirms that the endpoint returned an audio range, not that AVPlayer playback has been verified on an iOS device, and not full-track access or a guarantee of future availability.

### BhariyaMusic

The README documents `prepare`, `fetch`, and `audio` routes at `https://bhindi1.ddns.net/music/api`. On 2026-10-27, the host failed DNS resolution (`bhindi1.ddns.net` returned no address), so endpoint status, response payloads, redirects, playback, expiry, and rate limits could not be verified. Repository source shows YouTube URL extraction via `yt-dlp`; no authorized full-track contract was verified. The app probes only the documented `prepare` route, validates a successful response as JSON without assuming undocumented fields, then reports that the integration is not verified. It does not follow up to fetch or play audio.

## Playback and library

AVPlayer accepts imported local files and provider tracks only when their model has an eligible playback URL. The iTunes source currently exposes previews only. Imported audio is copied to Application Support for offline playback. Favorites, playlists, recent items, queue metadata, and preferences are stored as local JSON. Saving remote metadata does not download audio.

Background audio is enabled in `Info.plist`; AVAudioSession interruptions and Lock Screen transport commands are wired. These integrations still require simulator/device verification from Xcode.

## Current environment limitation

The implementation workspace used for this project is Windows and has no Swift or Xcode tools installed. The Xcode build, XCTest run, simulator inspection, and physical-device audio checks must be run on a Mac with Xcode.

## Run build and unit tests from Windows

The repository includes a GitHub Actions workflow at `.github/workflows/ios-tests.yml`. It uses a hosted macOS 26 runner with Xcode 26 to build the project and run the XCTest suite in an iPhone 17 simulator whenever you push, open a pull request, or manually start the workflow. The Xcode result bundle is attached to the Actions run as an artifact.

To use it, create a GitHub repository, then from this folder in PowerShell run:

```powershell
git init -b main
git add .
git commit -m "Add Musi App"
git remote add origin https://github.com/YOUR-ACCOUNT/YOUR-REPOSITORY.git
git push -u origin main
```

Replace the remote with your repository URL. Open the repository’s **Actions** tab to see the build and test logs. GitHub-hosted macOS runners are free and unlimited for public repositories; private repositories use the account’s included Actions minutes and then may incur charges.

This workflow verifies compilation and automated tests, but it does not provide an interactive simulator window on Windows. Manual UI, Lock Screen, and real-device audio checks still require access to an Apple device or a remote Mac/device testing service.
