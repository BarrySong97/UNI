# Milestone 3: Documentation Improvements

**Priority**: High
**Depends on**: None (can run in parallel with Milestones 1-2)

---

## Objective

Create comprehensive documentation to improve developer experience, facilitate pub.dev publication, and enable community contributions.

---

## Current State

| Aspect | Status |
|--------|--------|
| README | Basic setup instructions only |
| API docs | Disabled (`public_member_api_docs` commented out) |
| Code comments | Selective (591 doc comments) |
| Usage examples | None in documentation |
| Example app | Exists but lacks explanatory comments |

---

## Tasks

### 3.1 Enable and Complete API Documentation

**File**: `flureadium_platform_interface/analysis_options.yaml`

```yaml
linter:
  rules:
    public_member_api_docs: true  # Uncomment this line
```

**Priority classes to document**:

#### Flureadium Singleton
```dart
/// Main entry point for the Flureadium plugin.
///
/// Provides a unified API for reading EPUB publications, playing audiobooks,
/// and using text-to-speech across all supported platforms.
///
/// ## Getting Started
///
/// ```dart
/// final flureadium = Flureadium();
///
/// // Open a publication
/// final publication = await flureadium.openPublication('file:///book.epub');
///
/// // Listen for position changes
/// flureadium.onTextLocatorChanged.listen((locator) {
///   print('Current position: ${locator?.locations?.totalProgression}');
/// });
/// ```
///
/// ## Reading Modes
///
/// Flureadium supports multiple reading modes:
/// - **Visual reading**: Navigate through EPUB pages with [goLeft]/[goRight]
/// - **Text-to-speech**: Enable with [ttsEnable], control with [play]/[pause]
/// - **Audiobook**: Enable with [audioEnable] for pre-recorded audio
///
/// See also:
/// - [Publication] for the publication data model
/// - [Locator] for position tracking
/// - [EPUBPreferences] for visual customization
class Flureadium {
```

#### Publication Model
```dart
/// Represents a Readium Web Publication Manifest (RWPM).
///
/// A publication contains all metadata, content structure, and resources
/// needed to render an ebook, audiobook, or comic.
///
/// ## Structure
///
/// ```
/// Publication
/// ├── metadata (title, author, language, etc.)
/// ├── readingOrder (sequential content spine)
/// ├── resources (images, stylesheets, fonts)
/// ├── tableOfContents (navigation structure)
/// └── subCollections (page-list, landmarks, etc.)
/// ```
///
/// ## Common Operations
///
/// ```dart
/// // Find a content document by href
/// final link = publication.linkWithHref('chapter1.xhtml');
///
/// // Get the cover image
/// final coverUrl = publication.coverUri;
///
/// // Convert a TOC link to a locator for navigation
/// final locator = publication.locatorFromLink(tocEntry);
/// ```
class Publication {
```

#### Locator Model
```dart
/// Precise position marker within a publication.
///
/// A locator identifies a specific location using multiple coordinate systems
/// to ensure accurate positioning across different reading systems.
///
/// ## Components
///
/// - [href]: Content document reference (e.g., 'chapter1.xhtml')
/// - [type]: Media type of the resource
/// - [locations]: Numeric and structural position data
/// - [text]: Textual context around the position
///
/// ## Example
///
/// ```dart
/// final locator = Locator(
///   href: 'chapter1.xhtml',
///   type: 'application/xhtml+xml',
///   locations: Locations(
///     position: 1,
///     progression: 0.5,
///     totalProgression: 0.25,
///   ),
///   text: LocatorText(
///     before: 'The quick brown ',
///     highlight: 'fox',
///     after: ' jumps over the lazy dog.',
///   ),
/// );
/// ```
///
/// See also:
/// - [Locations] for position coordinate details
/// - [LocatorText] for text context
class Locator {
```

### 3.2 Comprehensive README

**File**: `flureadium/README.md`

```markdown
# Flureadium

A comprehensive Flutter plugin for reading EPUB ebooks, audiobooks, and comics using the [Readium](https://readium.org/) toolkits.

[![pub package](https://img.shields.io/pub/v/flureadium.svg)](https://pub.dev/packages/flureadium)
[![CI](https://github.com/user/flureadium/actions/workflows/test.yml/badge.svg)](https://github.com/user/flureadium/actions)
[![codecov](https://codecov.io/gh/user/flureadium/branch/main/graph/badge.svg)](https://codecov.io/gh/user/flureadium)

## Features

- **EPUB Reading**: Full EPUB 2/3 support with customizable typography
- **Audiobook Playback**: Native audio with background playback support
- **Text-to-Speech**: Platform TTS with voice selection and rate control
- **Synchronized Audio**: Media overlay support for read-along experiences
- **Highlighting**: Decoration API for bookmarks, highlights, and annotations
- **Cross-Platform**: Android, iOS, macOS, and Web support

## Quick Start

### Installation

```yaml
dependencies:
  flureadium: ^1.0.0
```

### Platform Setup

<details>
<summary>Android</summary>

1. Set minimum SDK version in `android/app/build.gradle`:
```groovy
android {
    defaultConfig {
        minSdkVersion 24
    }
}
```

2. Change `MainActivity` to extend `FlutterFragmentActivity`:
```kotlin
class MainActivity: FlutterFragmentActivity()
```

</details>

<details>
<summary>iOS</summary>

Add Readium pods to `ios/Podfile`:
```ruby
pod 'ReadiumShared', podspec: 'https://raw.githubusercontent.com/readium/swift-toolkit/3.5.0/Support/CocoaPods/ReadiumShared.podspec'
# ... (see full setup in documentation)
```

</details>

<details>
<summary>Web</summary>

1. Copy JavaScript file:
```bash
dart run flureadium:copy_js_file web/
```

2. Add to `index.html`:
```html
<script src="readiumReader.js" defer></script>
```

</details>

### Basic Usage

```dart
import 'package:flureadium/flureadium.dart';

// Get the singleton instance
final flureadium = Flureadium();

// Open a publication
final publication = await flureadium.openPublication('file:///path/to/book.epub');

// Display in your widget tree
ReaderWidget(
  onReaderCreated: (controller) {
    // Reader is ready
  },
)

// Navigate
await flureadium.goRight();
await flureadium.goToLocator(savedPosition);

// Listen for position changes
flureadium.onTextLocatorChanged.listen((locator) {
  saveReadingPosition(locator);
});
```

## Documentation

- [API Reference](https://pub.dev/documentation/flureadium/latest/)
- [Example App](example/)
- [Migration Guide](MIGRATION.md)

## Supported Formats

| Format | Visual | TTS | Audio | Sync |
|--------|--------|-----|-------|------|
| EPUB 2 | ✅ | ✅ | - | ✅ |
| EPUB 3 | ✅ | ✅ | ✅ | ✅ |
| WebPub | ✅ | ✅ | ✅ | ✅ |
| PDF | ✅ | ❌ | - | - |

## Contributing

Contributions are welcome! Please read our [Contributing Guide](CONTRIBUTING.md).

## License

[License details]

## Acknowledgments

Built on the excellent [Readium](https://readium.org/) project.
```

### 3.3 API Reference Generation

**File**: `flureadium/dartdoc_options.yaml`

```yaml
dartdoc:
  name: Flureadium
  description: Flutter plugin for Readium ebook reading

  categories:
    "Core":
      markdown: doc/categories/core.md
    "Models":
      markdown: doc/categories/models.md
    "Preferences":
      markdown: doc/categories/preferences.md
    "Navigation":
      markdown: doc/categories/navigation.md

  categoryOrder:
    - Core
    - Models
    - Preferences
    - Navigation

  exclude:
    - 'package:flureadium/src/**'
```

Add generation script:

```bash
# Generate API docs
dart doc flureadium_platform_interface
dart doc flureadium

# Serve locally
dart pub global activate dhttpd
dhttpd --path flureadium/doc/api
```

### 3.4 Usage Examples

**File**: `flureadium/example/README.md`

```markdown
# Flureadium Example

This example demonstrates all major features of the Flureadium plugin.

## Running the Example

```bash
cd flureadium/example
flutter run
```

## Features Demonstrated

### Opening Publications

```dart
// From local file
final pub = await flureadium.openPublication('file:///path/to/book.epub');

// From URL with authentication
await flureadium.setCustomHeaders({'Authorization': 'Bearer token'});
final pub = await flureadium.openPublication('https://example.com/book.epub');
```

### Visual Reading

```dart
// Customize appearance
await flureadium.setEPUBPreferences(EPUBPreferences(
  fontFamily: 'Georgia',
  fontSize: 120,  // 1.2em
  backgroundColor: Color(0xFFF5E6D3),  // Sepia
  pageMargins: 0.1,  // 10% margins
));

// Navigate
await flureadium.goLeft();
await flureadium.goRight();
await flureadium.goToLocator(savedLocator);

// Jump to TOC entry
await flureadium.goByLink(tocLink, publication);
```

### Text-to-Speech

```dart
// Get available voices
final voices = await flureadium.ttsGetAvailableVoices();

// Enable TTS with preferences
await flureadium.ttsEnable(TTSPreferences(
  rate: 1.2,   // 20% faster
  pitch: 1.0,  // Normal pitch
));

// Select voice
await flureadium.ttsSetVoice(voices.first.id, 'en-US');

// Control playback
await flureadium.play();
await flureadium.pause();
await flureadium.next();  // Skip to next sentence
```

### Audiobook Playback

```dart
// Enable audio navigator
await flureadium.audioEnable(
  AudioPreferences(playbackRate: 1.0),
  fromLocator: savedPosition,
);

// Control playback
await flureadium.play();
await flureadium.audioSeekBy(Duration(seconds: 30));  // Skip forward

// Listen for position updates
flureadium.onTimebasedPlayerStateChanged.listen((state) {
  print('Position: ${state.currentOffset}');
  print('Duration: ${state.currentDuration}');
});
```

### Highlighting

```dart
// Add a highlight
await flureadium.applyDecorations('highlights', [
  ReaderDecoration(
    id: 'highlight-1',
    locator: selectedLocator,
    style: DecorationStyle.highlight,
  ),
]);

// Add a bookmark
await flureadium.applyDecorations('bookmarks', [
  ReaderDecoration(
    id: 'bookmark-1',
    locator: currentLocator,
    style: DecorationStyle.underline,
  ),
]);
```

## State Management

The example uses BLoC pattern for state management. Key blocs:

- `PublicationBloc`: Manages publication loading/closing
- `PlayerControlsBloc`: Handles playback state
- `TextSettingsBloc`: Manages visual preferences
- `TTSSettingsBloc`: Manages TTS configuration
```

### 3.5 CONTRIBUTING.md

**File**: `CONTRIBUTING.md`

```markdown
# Contributing to Flureadium

Thank you for your interest in contributing!

## Development Setup

1. Clone the repository:
```bash
git clone https://github.com/user/flureadium.git
cd flureadium
```

2. Install dependencies:
```bash
cd flureadium_platform_interface && flutter pub get
cd ../flureadium && flutter pub get
cd example && flutter pub get
```

3. Run tests:
```bash
flutter test
```

## Code Style

- Run `dart format` before committing
- Follow existing code patterns
- Add documentation for public APIs
- Write tests for new features

## Pull Request Process

1. Create a feature branch from `develop`
2. Make your changes with tests
3. Ensure CI passes
4. Request review

## Reporting Issues

Please include:
- Flutter version (`flutter --version`)
- Platform (Android/iOS/Web)
- Minimal reproduction code
- Expected vs actual behavior
```

---

## Documentation Structure

```
flureadium/
├── README.md                    # Main package README
├── CHANGELOG.md                 # Version history
├── CONTRIBUTING.md              # Contribution guide
├── MIGRATION.md                 # Version migration guide
├── dartdoc_options.yaml         # API doc configuration
├── doc/
│   └── categories/
│       ├── core.md
│       ├── models.md
│       ├── preferences.md
│       └── navigation.md
└── example/
    └── README.md                # Example documentation

flureadium_platform_interface/
├── README.md                    # Interface package README
└── CHANGELOG.md
```

---

## Success Criteria

| Requirement | Target |
|-------------|--------|
| All public APIs documented | 100% |
| README with examples | Complete |
| API reference generated | Hosted |
| Example app documented | Complete |
| Contributing guide | Present |
| No dartdoc warnings | 0 warnings |

---

*Part of [Flureadium Analysis](ANALYSIS.md)*
