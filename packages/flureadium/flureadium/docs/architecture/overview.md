# Architecture Overview

This document describes the high-level architecture of the Flureadium plugin.

## Package Structure

Flureadium is organized as a monorepo with multiple packages:

```
flureadium/
├── flureadium/                    # Main Flutter plugin
│   ├── lib/                       # Dart source code
│   ├── android/                   # Android implementation (Kotlin)
│   ├── ios/                       # iOS implementation (Swift)
│   ├── macos/                     # macOS implementation (Swift)
│   ├── web/                       # Web implementation (TypeScript)
│   └── example/                   # Example Flutter app
│
├── flureadium_platform_interface/ # Platform interface
│   └── lib/                       # Shared types and contracts
│
└── project/                       # Project documentation
```

## Layer Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Flutter Application                       │
├─────────────────────────────────────────────────────────────┤
│                      Flureadium API                          │
│  ┌──────────────────┐  ┌──────────────────┐                 │
│  │   Flureadium     │  │  ReaderWidget    │                 │
│  │   (singleton)    │  │  (UI component)  │                 │
│  └────────┬─────────┘  └────────┬─────────┘                 │
├───────────┴─────────────────────┴───────────────────────────┤
│                 Platform Interface Layer                     │
│  ┌──────────────────────────────────────────────────────┐   │
│  │              FlureadiumPlatform                       │   │
│  │  (abstract class defining platform contract)          │   │
│  └────────────────────────┬─────────────────────────────┘   │
├───────────────────────────┴─────────────────────────────────┤
│                   Platform Implementations                   │
│  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌──────────┐ │
│  │  Android   │ │    iOS     │ │   macOS    │ │   Web    │ │
│  │  (Kotlin)  │ │  (Swift)   │ │  (Swift)   │ │   (TS)   │ │
│  └─────┬──────┘ └─────┬──────┘ └─────┬──────┘ └────┬─────┘ │
├────────┴──────────────┴──────────────┴─────────────┴────────┤
│                    Readium Toolkits                          │
│  ┌────────────────┐ ┌────────────────┐ ┌──────────────────┐ │
│  │ Kotlin Toolkit │ │ Swift Toolkit  │ │    TS Toolkit    │ │
│  └────────────────┘ └────────────────┘ └──────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Main Package (flureadium/)

### Dart Layer

```
lib/
├── flureadium.dart           # Main singleton API
├── reader_widget.dart        # Native reader widget
├── reader_channel.dart       # Method channel for widget
├── reader_widget_switch.dart # Platform-specific widget selection
├── reader_widget_web.dart    # Web-specific widget
└── src/
    ├── reader/               # Reader lifecycle mixins
    │   ├── orientation_handler_mixin.dart
    │   ├── reader_lifecycle_mixin.dart
    │   └── wakelock_manager_mixin.dart
    ├── utils/                # Utilities
    │   ├── navigation_helper.dart
    │   └── toc_matcher.dart
    └── web/                  # Web-specific code
```

### Flureadium Singleton

The main API entry point. Provides:
- Publication lifecycle (open, close)
- Navigation (goLeft, goRight, goToLocator)
- Playback (TTS, audiobook)
- Preferences and decorations

### ReaderWidget

Platform-specific native view wrapper:
- Android: `PlatformViewLink` with `AndroidViewSurface`
- iOS: `UiKitView`
- Web: Custom HTML container

Includes mixins for:
- **WakelockManagerMixin**: Keeps screen on during reading
- **ReaderLifecycleMixin**: Manages widget registration
- **OrientationHandlerMixin**: Handles orientation changes

## Platform Interface (flureadium_platform_interface/)

Defines the contract between Dart and native code:

```
lib/
├── flureadium_platform_interface.dart  # Abstract platform class
├── method_channel_flureadium.dart      # Default implementation
└── src/
    ├── exceptions/          # Exception types
    ├── extensions/          # Utility extensions
    ├── reader/              # Reader types
    │   ├── reader_epub_preferences.dart
    │   ├── reader_tts_preferences.dart
    │   ├── reader_audio_preferences.dart
    │   ├── reader_decoration.dart
    │   └── reader_tts_voice.dart
    ├── shared/              # Shared models
    │   ├── publication/     # Publication, Locator, Link, Metadata
    │   └── mediatype.dart
    └── utils/               # Utilities (logging, JSON)
```

### FlureadiumPlatform

Abstract class defining the platform contract:

```dart
abstract class FlureadiumPlatform extends PlatformInterface {
  Future<Publication> openPublication(String pubUrl);
  Future<void> closePublication();
  Future<void> goLeft();
  Future<void> goRight();
  Future<bool> goToLocator(Locator locator);
  // ... more methods
}
```

### MethodChannelFlureadium

Default implementation using Flutter platform channels:
- Method channel for synchronous calls
- Event channels for streaming data

## Native Implementations

### Android (Kotlin)

```
android/src/main/kotlin/dev/mulev/flureadium/
├── FlureadiumPlugin.kt        # Flutter plugin registration
├── ReadiumReaderView.kt       # Native reader view
├── NavigatorWrapper.kt        # Readium navigator wrapper
└── ...
```

Uses:
- Readium Kotlin Toolkit
- Fragment-based navigation
- Platform views

### iOS (Swift)

```
ios/Sources/flureadium/
├── FlureadiumPlugin.swift     # Flutter plugin registration
├── ReadiumReaderView.swift    # Native reader view
├── NavigatorController.swift  # Navigation handling
└── ...
```

Uses:
- Readium Swift Toolkit 3.5.0
- UIKit views embedded via UiKitView
- GCDWebServer for local content serving

### Web (TypeScript)

```
web/_scripts/
├── ReadiumReader.ts           # Main entry point
├── epubNavigator.ts           # EPUB navigation
├── webpubNavigator.ts         # WebPub navigation
└── preferences.ts             # Preference handling
```

Uses:
- Readium TypeScript Toolkit
- JavaScript interop with Dart
- CSS injection for styling

## Communication Flow

### Method Channels

```
Dart (Flureadium)
    │
    ▼ invokeMethod()
MethodChannel('dev.mulev.flureadium')
    │
    ▼
Native (FlureadiumPlugin)
    │
    ▼
Readium Toolkit
```

### Event Channels

```
Readium Toolkit
    │
    ▼ callback
Native (FlureadiumPlugin)
    │
    ▼ EventChannel
MethodChannel('dev.mulev.flureadium')
    │
    ▼ Stream
Dart (onTextLocatorChanged, etc.)
```

### Widget Channels

```
Dart (ReadiumReaderWidget)
    │
    ▼ invokeMethod()
ReadiumReaderChannel('dev.mulev.flureadium/ReadiumReaderWidget:id')
    │
    ▼
Native (ReadiumReaderView)
    │
    ▼
Readium Navigator
```

## Data Flow

### Opening a Publication

```
1. Flutter calls openPublication(path)
2. MethodChannel sends to native
3. Native uses Readium to parse EPUB
4. Publication manifest returned as JSON
5. Dart parses JSON to Publication object
6. ReaderWidget created with Publication
7. Native view renders content
```

### Position Updates

```
1. User navigates (scroll, tap, etc.)
2. Readium navigator updates position
3. Native sends Locator via EventChannel
4. Dart receives and broadcasts via Stream
5. App saves progress, updates UI
```

## Key Design Decisions

### Singleton Pattern

`Flureadium` uses singleton pattern for:
- Centralized state management
- Consistent API access
- Simplified lifecycle management

### Platform Interface Pattern

Follows Flutter plugin platform interface pattern:
- Abstract class in separate package
- Platform implementations can be swapped
- Testable with mocks

### Readium Integration

Wraps Readium toolkits rather than reimplementing:
- Leverages proven EPUB rendering
- Access to advanced features (TTS, audio)
- Cross-platform consistency

### JSON Serialization

All models serialize to/from JSON:
- Platform communication
- Persistence
- Debugging

## See Also

- [Platform Channels](platform-channels.md) - Detailed channel documentation
- [Readium Integration](readium-integration.md) - How we wrap Readium
- [Platform-Specific Docs](../platform-specific/) - Platform implementation details
