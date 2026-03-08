# Android Platform

Android-specific setup and implementation details.

## Requirements

- Android SDK 24+ (Android 7.0 Nougat)
- Kotlin 1.8+
- Gradle 8.0+

## Setup

### 1. Add JitPack Repository

The Readium Pdfium adapter requires dependencies from JitPack. Add JitPack to your `android/build.gradle`:

```groovy
allprojects {
    repositories {
        google()
        mavenCentral()
        maven { url 'https://jitpack.io' }  // Required for Readium PDF support
    }
}
```

### 2. Minimum SDK Version

In `android/app/build.gradle`:

```groovy
android {
    defaultConfig {
        minSdkVersion 24
    }
}
```

### 3. FlutterFragmentActivity

Change your `MainActivity` to extend `FlutterFragmentActivity`:

```kotlin
// android/app/src/main/kotlin/.../MainActivity.kt
package com.example.myapp

import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity: FlutterFragmentActivity() {
}
```

**Why?** Flureadium uses platform views that require Fragment support.

### 4. Permissions

For TTS and audiobook features, add to `AndroidManifest.xml`:

```xml
<manifest>
    <uses-permission android:name="android.permission.WAKE_LOCK" />

    <!-- For network-based publications -->
    <uses-permission android:name="android.permission.INTERNET" />
</manifest>
```

### 5. ProGuard Rules (Optional)

If using ProGuard/R8, add to `android/app/proguard-rules.pro`:

```proguard
# Readium
-keep class org.readium.** { *; }
-keep class org.joda.time.** { *; }

# Flureadium
-keep class dev.mulev.flureadium.** { *; }
```

## Implementation Details

### Plugin Structure

```
android/src/main/kotlin/dev/mulev/flureadium/
├── FlureadiumPlugin.kt          # Plugin registration
├── MethodCallHandler.kt         # Method channel handler
├── ReadiumManager.kt            # Readium lifecycle
├── ReadiumReaderViewFactory.kt  # Platform view factory
├── ReadiumReaderView.kt         # Native reader view (EPUB)
├── ReadiumReaderWidget.kt       # Widget wrapper
├── FlutterPdfPreferences.kt     # PDF preferences mapping
├── fragments/
│   └── PdfReaderFragment.kt     # PDF reader fragment
├── models/
│   └── PdfReaderViewModel.kt    # PDF reader state
└── navigators/
    └── PdfNavigator.kt          # PDF navigation controller
```

### Event Channels

All four Flutter EventChannels are registered in `ReadiumReader.attach()`:

| Channel | Kotlin class | Events |
|---|---|---|
| `dev.mulev.flureadium/reader-status` | `ReaderStatusEventChannel` | `"loading"`, `"ready"`, `"closed"` |
| `dev.mulev.flureadium/error` | `ErrorEventChannel` | `{ message, code, data }` maps |
| `dev.mulev.flureadium/text-locator` | `TextLocatorEventChannel` | Locator JSON strings |
| `dev.mulev.flureadium/timebased-state` | `TimedBasedStateEventChannel` | Playback state maps |

Reader status lifecycle:
- `"loading"` — emitted from `ReadiumReaderWidget.init` when the native view is created
- `"ready"` — emitted from `onVisualReaderIsReady()` when Readium signals the reader is ready
- `"closed"` — emitted from `ReadiumReaderWidget.dispose()` before tearing down the navigator

### Platform View

Uses `PlatformViewLink` with `AndroidViewSurface` for high-performance rendering:

```kotlin
class ReadiumReaderViewFactory(
    private val messenger: BinaryMessenger
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return ReadiumReaderView(context, viewId, messenger, args as? Map<*, *>)
    }
}
```

### Readium Integration

Uses Readium Kotlin Toolkit:
- `Streamer` for EPUB parsing
- `Navigator` for content display
- `TTS` and `MediaPlayer` for audio
- `PdfiumNavigator` for PDF rendering (via Pdfium adapter)

### PDF Support

PDF support is implemented using Readium's Pdfium adapter, which provides native PDF rendering via Android's Pdfium library.

**How It Works:**

The `PdfNavigator` class wraps Readium's PDF navigator and provides:
- Page-by-page navigation with edge tap detection
- Horizontal and vertical scroll modes
- Single page and double-page spread layouts
- Zoom and pan gestures

**Configuration:**

PDF preferences can be set via `setPDFPreferences()`:

```dart
await flureadium.setPDFPreferences(PDFPreferences(
  fit: PDFFit.width,
  scrollMode: PDFScrollMode.horizontal,
  pageLayout: PDFPageLayout.single,
));
```

**Files:**
- `PdfNavigator.kt` - Main PDF navigation controller
- `PdfReaderFragment.kt` - Android Fragment hosting the PDF view
- `FlutterPdfPreferences.kt` - Maps Flutter preferences to Readium

## Edge Tap and Swipe Navigation

Android supports the same configurable gesture overlay as iOS via `setNavigationConfig()`.

### Overview

A transparent `EdgeTapInterceptView` overlay is placed on top of the Readium navigator
(both EPUB and PDF). It intercepts touches in the left and right edge zones and fires
navigation callbacks; center touches always pass through to the reader content.

### setNavigationConfig

```dart
await flureadium.setNavigationConfig(NavigationConfig(
  enableEdgeTapNavigation: true,   // tap left/right edges to turn pages
  enableSwipeNavigation: true,     // horizontal fling to turn pages
  edgeTapAreaPoints: 60,           // edge zone width in dp (44–120, clamped)
));
```

| Field | Type | Default | Description |
|---|---|---|---|
| `enableEdgeTapNavigation` | `bool?` | enabled | Tap in the edge zone → navigate |
| `enableSwipeNavigation` | `bool?` | enabled | Horizontal fling → navigate |
| `edgeTapAreaPoints` | `double?` | 44 dp | Edge zone width, clamped to 44–120 dp |

`null` fields are treated as **enabled** (matching iOS semantics).

### Scroll Mode (EPUB only)

When the EPUB reader switches to vertical scroll mode (via `setPreferences` with
`verticalScroll: true`), the overlay automatically disables all gesture interception
so Readium's WebView can handle native scrolling. Gestures are re-enabled when
scroll mode is turned off.

PDF is always paginated; scroll mode does not apply.

### Implementation

| File | Role |
|---|---|
| `FlutterNavigationConfig.kt` | Data class mirroring the Flutter config map |
| `EdgeTapInterceptView.kt` | Transparent FrameLayout overlay; intercepts edge touches |
| `EpubReaderFragment.kt` | Creates and tears down the overlay per lifecycle; propagates scroll mode |
| `PdfReaderFragment.kt` | Creates and tears down the overlay per lifecycle |
| `EpubNavigator.kt` / `PdfNavigator.kt` | Delegates `setNavigationConfig` / `setScrollMode` to the fragment |
| `ReadiumReader.kt` | Exposes `epubSetNavigationConfig`, `epubSetScrollMode`, `pdfSetNavigationConfig` |
| `ReadiumReaderWidget.kt` | Handles `setNavigationConfig` method call; detects scroll mode from `setPreferences` |

#### Touch dispatch design

`EdgeTapInterceptView` overrides `dispatchTouchEvent` rather than `onInterceptTouchEvent` +
`onTouchEvent`. The reason matters for future maintenance:

- `onInterceptTouchEvent` returning `true` causes the ViewGroup to call `onTouchEvent`.
- `onTouchEvent` returns `gestureDetector.onTouchEvent()`, which returns `onDown() = false`
  (the `SimpleOnGestureListener` default).
- That `false` propagates out of `dispatchTouchEvent`, so the **parent `FrameLayout` never
  records this view as the touch target** — `ACTION_UP` never arrives, and
  `onSingleTapConfirmed` never fires.

`dispatchTouchEvent` avoids this by returning `true` unconditionally for any `ACTION_DOWN`
that lands in an edge zone (claiming the gesture sequence), and `false` for centre touches
(passing them straight to the Readium WebView / PDF view).

## Troubleshooting

### "MainActivity cannot be cast to FragmentActivity"

Ensure MainActivity extends `FlutterFragmentActivity`.

### Build fails with "Duplicate class"

Add to `android/app/build.gradle`:
```groovy
android {
    packagingOptions {
        exclude 'META-INF/DEPENDENCIES'
        exclude 'META-INF/LICENSE'
    }
}
```

### TTS not working

1. Check TTS engine is installed (Settings > Accessibility > TTS)
2. Download language data if prompted
3. Test with system TTS settings

### Edge taps not responding

If edge taps appear in Flutter's `Listener` logs but no navigation occurs:

1. Check logcat for `D/EdgeTapInterceptView: dispatchTouchEvent ACTION_DOWN x=... claimed=true`.
   If `claimed=false` for a tap at the screen edge, the tap coordinate in **dp** is outside
   the configured zone — verify `edgeTapAreaPoints` and screen density.
2. If there are no `EdgeTapInterceptView` logs at all, the overlay was not created. Confirm
   `attachNavigator()` ran and `view as? FrameLayout` succeeded (the fragment root must be a
   `FrameLayout`, which it is by default via `fragment_reader.xml`).
3. In EPUB scroll mode, all overlay gestures are intentionally disabled; check that
   `setScrollMode(false)` was called when leaving scroll mode.

### WebView rendering issues

Enable hardware acceleration:
```xml
<application android:hardwareAccelerated="true">
```

## See Also

- [Installation Guide](../getting-started/installation.md)
- [Architecture Overview](../architecture/overview.md)
- [Troubleshooting](../troubleshooting.md)
