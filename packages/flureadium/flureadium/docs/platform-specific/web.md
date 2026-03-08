# Web Platform

> **Work in Progress** — Web support is functional at the infrastructure level (`ReadiumReaderWidget` renders, JS interop bridges are in place) but publication loading has known limitations. EPUB files served via HTTP URL are not reliably opened by the Readium JS navigator. WebPub loading from remote URLs is under active investigation. Integration test coverage on web is limited to the app-launch smoke test. Expect rough edges and API gaps compared to Android and iOS.

Web-specific setup and implementation details.

## Requirements

- Modern browser with JavaScript ES6+ support
- Flutter Web

## Setup

### 1. Copy JavaScript File

Run from your project root:

```bash
dart run flureadium:copy_js_file web/
```

This copies `readiumReader.js` to your web directory.

### 2. Add Script Tags

In `web/index.html`, add to the `<head>` section:

```html
<head>
  <!-- Other head content -->

  <!-- Flutter initialization -->
  <script src="flutter.js" defer></script>

  <!-- Flureadium reader -->
  <script src="readiumReader.js" defer></script>
</head>
```

If you placed the JS file in a subdirectory:
```html
<script src="scripts/readiumReader.js" defer></script>
```

## Implementation Details

### Architecture

```
Web Implementation
├── Dart Layer
│   ├── flureadium_web.dart      # Web plugin registration
│   ├── reader_widget_web.dart   # Web reader widget
│   └── js_publication_channel.dart # JS interop
└── TypeScript Layer
    ├── ReadiumReader.ts         # Main entry point
    ├── epubNavigator.ts         # EPUB navigation
    ├── webpubNavigator.ts       # WebPub navigation
    ├── preferences.ts           # CSS preferences
    └── decorations.ts           # Highlight handling
```

### JavaScript Interop

Uses `dart:js_interop` for communication:

```dart
@JS('ReadiumReader')
external JSObject get readiumReader;

void goLeft() {
  readiumReader.callMethod('goLeft'.toJS, []);
}
```

### Readium CSS

Web uses Readium CSS for styling. Preferences map to CSS variables:

| Preference | CSS Variable |
|------------|--------------|
| fontFamily | `--USER__fontFamily` |
| fontSize | `--USER__fontSize` |
| textColor | `--USER__textColor` |
| backgroundColor | `--USER__backgroundColor` |

See [Readium CSS documentation](https://github.com/readium/css) for all options.

### Publication Rendering

1. EPUB is fetched and parsed
2. Content extracted to HTML
3. Readium CSS injected
4. Rendered in iframe/container
5. Navigation via JavaScript API

## Preferences

Web preferences support additional Readium CSS options:

```dart
// Basic preferences work the same
await flureadium.setEPUBPreferences(EPUBPreferences(
  fontFamily: 'Georgia',
  fontSize: 120,
  backgroundColor: Color(0xFFFFFFFF),
  textColor: Color(0xFF000000),
));
```

For advanced CSS options, see [Readium CSS Types](https://github.com/readium/ts-toolkit/blob/develop/navigator/src/preferences/Types.ts).

## Limitations

### Known Issues (Work in Progress)

| Feature | Status | Notes |
|---------|--------|-------|
| EPUB from assets | Broken | Packed EPUB served via HTTP URL is not properly opened by the Readium JS navigator |
| WebPub from remote URL | Broken | `loadPublication` / `getPublication` call fails before `ReadiumWebView` container is mounted |
| TTS | Not implemented | Throws `UnimplementedError` |
| Audiobook playback | Not implemented | Throws `UnimplementedError` |
| Custom HTTP headers | No-op | `setCustomHeaders` logs a warning and does nothing on web |
| Background Audio | No | Browser limitation |
| Lock Screen | No | Browser limitation |

### Features Available on Web

| Feature | Status |
|---------|--------|
| Widget renders | Yes — `ReadiumReaderWidget` mounts and displays via `HtmlElementView` |
| Navigation (goLeft/goRight) | Yes |
| EPUB preferences (font/color) | Yes |
| Decorations/highlights | No-op (logs warning) |

### Browser Compatibility

Tested on Chrome. Other browsers may work but are untested.

## Loading Publications

Publication loading on web is work in progress. The current implementation calls
`ReadiumReader.getPublication(url)` via JS interop, which requires the Readium JS navigator
to be ready. This works only after `ReadiumWebView` is mounted — creating a chicken-and-egg
dependency that is not yet resolved.

### From URL (currently broken)

```dart
// This silently fails on web — _publication stays null
final pub = await flureadium.openPublication('https://example.com/book.epub');
```

### From Assets (currently broken)

```dart
// Assets are resolved to absolute HTTP URLs, but the Readium JS navigator
// cannot open packed EPUB files served via HTTP on web
final pub = await flureadium.openPublication('/assets/books/sample.epub');
```

### CORS Considerations

For cross-origin publications, ensure server sends:
```
Access-Control-Allow-Origin: *
```

## Troubleshooting

### JavaScript File Not Found

1. Verify file exists in `web/` directory
2. Check script tag path in `index.html`
3. Clear browser cache

### "ReadiumReader is not defined"

Script loading order issue. Ensure:
1. `flutter.js` loads first
2. `readiumReader.js` loads before Flutter app

### CORS Errors

```
Access to fetch at 'file://' from origin 'http://localhost' has been blocked
```

Solution: Serve files via HTTP server, not file:// protocol.

### TTS Not Working

Web Speech API availability varies:
```dart
final voices = await flureadium.ttsGetAvailableVoices();
if (voices.isEmpty) {
  print('TTS not available in this browser');
}
```

### Slow Performance

1. Optimize EPUB size
2. Use paginated mode
3. Limit decorations
4. Consider lazy loading

## Development Tips

### Hot Reload

Web hot reload works with Flureadium:
```bash
flutter run -d chrome
```

### DevTools

Use browser DevTools to:
- Inspect rendered content
- Debug JavaScript
- Check network requests
- Profile performance

### Building for Production

```bash
flutter build web --release
```

Ensure `readiumReader.js` is included in build output.

## See Also

- [Installation Guide](../getting-started/installation.md)
- [Architecture Overview](../architecture/overview.md)
- [Troubleshooting](../troubleshooting.md)
