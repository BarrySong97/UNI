# Flureadium Documentation

Flureadium is a Flutter plugin that wraps the Readium toolkits for reading EPUB ebooks, audiobooks, and comics. It provides a unified cross-platform API supporting Android, iOS, macOS, and Web.

## Quick Links

| Section | Description |
|---------|-------------|
| [Getting Started](getting-started/) | Installation, quick start, and core concepts |
| [Guides](guides/) | Step-by-step tutorials for common tasks |
| [API Reference](api-reference/) | Complete API documentation |
| [Architecture](architecture/) | Technical design and implementation details |
| [Platform-Specific](platform-specific/) | Platform setup and native details |
| [Troubleshooting](troubleshooting.md) | Common issues and solutions |

## Getting Started

1. **[Installation](getting-started/installation.md)** - Set up Flureadium in your Flutter project
2. **[Quick Start](getting-started/quick-start.md)** - Get reading in 5 minutes
3. **[Concepts](getting-started/concepts.md)** - Understand Publications, Locators, and more

## Feature Guides

- **[EPUB Reading](guides/epub-reading.md)** - Visual EPUB navigation and customization
- **[Text-to-Speech](guides/text-to-speech.md)** - TTS integration and voice selection
- **[Audiobook Playback](guides/audiobook-playback.md)** - Playing pre-recorded audio
- **[Highlights & Annotations](guides/highlights-annotations.md)** - Adding visual decorations
- **[Saving Progress](guides/saving-progress.md)** - Persisting reading position
- **[Reader Preferences](guides/preferences.md)** - Customizing appearance
- **[Error Handling](guides/error-handling.md)** - Exception types and best practices

## API Reference

- **[Flureadium Class](api-reference/flureadium-class.md)** - Main singleton API
- **[ReaderWidget](api-reference/reader-widget.md)** - Reader display widget
- **[Publication](api-reference/publication.md)** - Publication data model
- **[Locator](api-reference/locator.md)** - Position tracking
- **[Preferences](api-reference/preferences.md)** - EPUB, TTS, and Audio preferences
- **[Decorations](api-reference/decorations.md)** - Highlights and bookmarks
- **[Streams & Events](api-reference/streams-events.md)** - Real-time updates

## Architecture

- **[Overview](architecture/overview.md)** - High-level architecture
- **[Platform Channels](architecture/platform-channels.md)** - Native communication
- **[Readium Integration](architecture/readium-integration.md)** - How we wrap Readium

## Platform Setup

- **[Android](platform-specific/android.md)** - Android-specific setup
- **[iOS](platform-specific/ios.md)** - iOS-specific setup
- **[macOS](platform-specific/macos.md)** - macOS-specific setup
- **[Web](platform-specific/web.md)** - Web-specific setup

## Supported Formats

| Format | Visual Reading | TTS | Audio | Media Overlays |
|--------|----------------|-----|-------|----------------|
| EPUB 2 | Yes | Yes | - | Yes |
| EPUB 3 | Yes | Yes | Yes | Yes |
| WebPub | Yes | Yes | Yes | Yes |
| PDF | Android, iOS | - | - | - |

> **Note:** PDF support status:
> - **Completed:** Format detection, preferences API, Android native navigator, iOS native navigator, Flutter widget layer integration, Epist migration
> - **In Progress:** Manual testing on both platforms

## Minimum Requirements

- Flutter 3.3.0+
- Dart SDK 3.8.0+
- Android: minSdkVersion 24
- iOS: 13.0+
- macOS: 10.15+

## Related Resources

- [Main README](../README.md) - Project overview
- [Contributing Guide](../../CONTRIBUTING.md) - How to contribute
- [Example App](../example/) - Working demo application

---

*Last updated: 2026-02-08*
