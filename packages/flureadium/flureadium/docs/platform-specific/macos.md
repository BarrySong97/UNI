# macOS Platform

macOS-specific setup and implementation details.

## Requirements

- macOS 10.15 (Catalina)+
- Xcode 14+
- CocoaPods

## Setup

### 1. Podfile Configuration

Similar to iOS, add Readium pods to `macos/Podfile`:

```ruby
platform :osx, '10.15'

target 'Runner' do
  use_frameworks!
  use_modular_headers!

  # PromiseKit dependency
  pod 'PromiseKit', '~> 8.1'

  # Readium toolkit pods (version 3.5.0)
  pod 'ReadiumShared', podspec: 'https://raw.githubusercontent.com/readium/swift-toolkit/3.5.0/Support/CocoaPods/ReadiumShared.podspec'
  pod 'ReadiumInternal', podspec: 'https://raw.githubusercontent.com/readium/swift-toolkit/3.5.0/Support/CocoaPods/ReadiumInternal.podspec'
  pod 'ReadiumStreamer', podspec: 'https://raw.githubusercontent.com/readium/swift-toolkit/3.5.0/Support/CocoaPods/ReadiumStreamer.podspec'
  pod 'ReadiumNavigator', podspec: 'https://raw.githubusercontent.com/readium/swift-toolkit/3.5.0/Support/CocoaPods/ReadiumNavigator.podspec'
  pod 'ReadiumOPDS', podspec: 'https://raw.githubusercontent.com/readium/swift-toolkit/3.5.0/Support/CocoaPods/ReadiumOPDS.podspec'
  pod 'ReadiumAdapterGCDWebServer', podspec: 'https://raw.githubusercontent.com/readium/swift-toolkit/3.5.0/Support/CocoaPods/ReadiumAdapterGCDWebServer.podspec'
  pod 'ReadiumZIPFoundation', podspec: 'https://raw.githubusercontent.com/readium/podspecs/refs/heads/main/ReadiumZIPFoundation/3.0.1/ReadiumZIPFoundation.podspec'

  flutter_install_all_macos_pods File.dirname(File.realpath(__FILE__))
end
```

Then run:
```bash
cd macos
pod install
```

### 2. Entitlements

#### Network Access

In `macos/Runner/DebugProfile.entitlements` and `macos/Runner/Release.entitlements`:

```xml
<key>com.apple.security.network.client</key>
<true/>
```

#### Local Server

For the local content server:

```xml
<key>com.apple.security.network.server</key>
<true/>
```

#### File Access

For reading local files:

```xml
<key>com.apple.security.files.user-selected.read-only</key>
<true/>
```

Or for broader access (if not sandboxed):
```xml
<key>com.apple.security.files.downloads.read-only</key>
<true/>
```

### 3. App Sandbox

If your app is sandboxed, ensure appropriate entitlements are set. For full functionality:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.network.server</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-only</key>
    <true/>
</dict>
</plist>
```

## Implementation Details

### Differences from iOS

macOS implementation is similar to iOS but uses:
- NSViewController instead of UIViewController
- NSView instead of UIView
- AppKit instead of UIKit

### Plugin Structure

```
macos/Sources/flureadium/
├── FlureadiumPlugin.swift
├── ReadiumManager.swift
├── ReadiumReaderView.swift
└── ...
```

### Window Management

macOS supports multiple windows. Each window can have its own reader:

```dart
// Works across multiple windows
final pub = await flureadium.openPublication(path);
```

## Keyboard Navigation

macOS readers typically support keyboard shortcuts:

| Key | Action |
|-----|--------|
| Left Arrow | Previous page |
| Right Arrow | Next page |
| Space | Next page |
| Shift+Space | Previous page |
| Home | Go to start |
| End | Go to end |

Implement keyboard handling in your Flutter app:
```dart
RawKeyboardListener(
  focusNode: _focusNode,
  onKey: (event) {
    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        flureadium.goLeft();
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        flureadium.goRight();
      }
    }
  },
  child: ReadiumReaderWidget(publication: pub),
)
```

## Troubleshooting

### Pod Install Fails

Same as iOS:
```bash
cd macos
pod deintegrate
pod cache clean --all
pod install
```

### Sandbox Issues

If files won't open:
1. Check entitlements include file access
2. Use file picker for user-selected files
3. Consider bookmark/security-scoped URLs

### TTS Voices

macOS has excellent TTS support:
```dart
final voices = await flureadium.ttsGetAvailableVoices();
// Many high-quality voices available
```

### Window Focus

If reader doesn't respond:
1. Ensure window has focus
2. Check keyboard event handling
3. Verify platform view is receiving events

## Distribution

### App Store

For Mac App Store:
1. Enable sandboxing
2. Set appropriate entitlements
3. Include privacy manifest

### Direct Distribution

For direct distribution:
1. Notarize the app
2. Consider sandboxing optional
3. Handle file access appropriately

## See Also

- [iOS Platform](ios.md) - Similar setup
- [Installation Guide](../getting-started/installation.md)
- [Troubleshooting](../troubleshooting.md)
