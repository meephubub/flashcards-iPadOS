# Flashcards iPadOS

A simple SwiftUI flashcards app for iOS/iPadOS.

## Building

This project uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the Xcode project from `project.yml`.

### Local (macOS with Xcode)

```bash
brew install xcodegen
xcodegen generate
open FlashcardsiPadOS.xcodeproj
```

### CI — Unsigned IPA (GitHub Actions)

A GitHub Actions workflow automatically builds an unsigned `.ipa` on every push to `main`.

1. Push your code to GitHub
2. Go to the **Actions** tab
3. Find the latest **Build Unsigned IPA** run
4. Download the `FlashcardsiPadOS-unsigned` artifact (contains the `.ipa`)

You can also trigger a build manually via **Actions → Build Unsigned IPA → Run workflow**.

## Sideloading

The IPA is **unsigned** — you cannot install it directly. Use one of these tools:

| Tool | Notes |
|------|-------|
| [AltStore](https://altstore.io) | Free, requires AltServer running on a PC/Mac |
| [Sideloadly](https://sideloadly.io) | Free, desktop app for Windows/macOS |
| [TrollStore](https://github.com/opa334/TrollStore) | No PC needed, but requires a compatible iOS version |

All of these will re-sign the app with your free Apple ID.

## Requirements

- iOS/iPadOS 16.0+
- No paid Apple Developer account required for sideloading
