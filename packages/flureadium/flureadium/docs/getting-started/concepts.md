# Core Concepts

Understanding these core concepts will help you effectively use Flureadium.

## Publication

A `Publication` represents a loaded ebook, audiobook, or comic. It follows the [Readium Web Publication Manifest (RWPM)](https://readium.org/webpub-manifest/) format.

### Structure

```
Publication
├── metadata          # Title, authors, language, etc.
├── readingOrder      # Sequential content spine (chapters)
├── resources         # Images, stylesheets, fonts
├── tableOfContents   # Navigation structure (TOC)
└── subCollections    # Page lists, landmarks, etc.
```

### Key Properties

```dart
final pub = await flureadium.openPublication('book.epub');

// Metadata
print(pub.metadata.title);           // "Book Title"
print(pub.metadata.authors);         // [Contributor(name: "Author")]
print(pub.metadata.language);        // ["en"]

// Identifier
print(pub.identifier);               // Unique ID or "unidentified"

// Cover image
final coverUrl = pub.coverUri;       // URI to cover image

// Table of contents
for (final link in pub.tableOfContents) {
  print('${link.title}: ${link.href}');
}

// Check publication type
if (pub.conformsToReadiumAudiobook) {
  // This is an audiobook
}
if (pub.conformsToReadiumEbook) {
  // This is an EPUB/ebook
}
if (pub.containsMediaOverlays) {
  // Has synchronized audio
}
```

### Finding Links

```dart
// Find a content document by href
final link = pub.linkWithHref('chapter1.xhtml');

// Find links by relation
final tocLink = pub.linkWithRel('toc');
final coverLinks = pub.linksWithRel('cover');

// Get links from subcollections
final pageList = pub.collectionLinks('page-list');
```

## Locator

A `Locator` precisely identifies a position within a publication. Use locators for:

- Saving and restoring reading position
- Bookmarks and highlights
- Search results
- Navigation targets

### Structure

```dart
Locator(
  href: 'chapter1.xhtml',           // Content document path
  type: 'application/xhtml+xml',    // Media type
  title: 'Chapter 1',               // Optional title
  locations: Locations(
    fragments: ['heading-1'],       // Fragment identifiers
    progression: 0.25,              // Position in resource (0-1)
    position: 5,                    // Absolute position index
    totalProgression: 0.1,          // Position in publication (0-1)
    cssSelector: '#paragraph-3',    // CSS selector
  ),
  text: LocatorText(
    before: 'context before ',      // Text before position
    highlight: 'selected text',     // Highlighted text
    after: ' context after',        // Text after position
  ),
)
```

### Key Properties

```dart
// Get the overall progress (0.0 to 1.0)
final progress = locator.locations?.totalProgression ?? 0;
print('${(progress * 100).toStringAsFixed(1)}% complete');

// Get href without fragment
final path = locator.hrefPath;  // "chapter1.xhtml" (no #anchor)

// Serialize to JSON string for storage
final json = locator.json;
// '{"href":"chapter1.xhtml","type":"application/xhtml+xml",...}'

// Deserialize from JSON
final restored = Locator.fromJsonString(json);
```

### Creating Locators

```dart
// From a TOC link
final tocLink = pub.tableOfContents.first;
final locator = pub.locatorFromLink(tocLink);

// From any link
final link = pub.linkWithHref('chapter1.xhtml');
final locator = link?.toLocator();

// Modify existing locator
final updated = locator.copyWith(
  title: 'New Title',
  locations: locator.locations?.copyWith(
    progression: 0.5,
  ),
);
```

## Link

A `Link` represents a reference to content or resources within the publication.

### Properties

```dart
Link(
  href: 'chapter1.xhtml',           // Resource path
  type: 'application/xhtml+xml',    // Media type
  title: 'Chapter 1',               // Optional title
  rel: ['contents'],                // Relations
  properties: Properties(...),       // Additional properties
  duration: Duration(minutes: 5),   // For audio resources
  children: [...],                  // Nested links (sub-chapters)
  alternates: [...],                // Alternate representations
)
```

### Common Uses

```dart
// Table of contents entries
for (final link in pub.tableOfContents) {
  print(link.title);  // Chapter title
  print(link.href);   // Target href

  // Nested chapters
  for (final child in link.children) {
    print('  ${child.title}');
  }
}

// Reading order (spine)
for (final link in pub.readingOrder) {
  print('${link.href}: ${link.type}');
}

// Resources
for (final link in pub.resources) {
  if (link.type?.startsWith('image/') == true) {
    print('Image: ${link.href}');
  }
}
```

## Reading Modes

Flureadium supports three reading modes:

### 1. Visual Reading

Display EPUB content with pagination or scrolling.

```dart
// Navigate pages
await flureadium.goLeft();
await flureadium.goRight();

// Jump to position
await flureadium.goToLocator(locator);

// Chapter navigation
await flureadium.skipToNext();
await flureadium.skipToPrevious();
```

### 2. Text-to-Speech (TTS)

Synthesize speech from text content.

```dart
// Enable TTS
await flureadium.ttsEnable(TTSPreferences(
  speed: 1.0,   // 1.0 = normal speed
  pitch: 1.0,
));

// Control playback
await flureadium.play(null);
await flureadium.pause();
await flureadium.next();      // Next sentence
await flureadium.previous();  // Previous sentence
```

### 3. Audiobook

Play pre-recorded audio content.

```dart
// Enable audio
await flureadium.audioEnable(
  prefs: AudioPreferences(speed: 1.0),
);

// Control playback
await flureadium.play(null);
await flureadium.audioSeekBy(Duration(seconds: 30));
await flureadium.next();      // Next track
await flureadium.previous();  // Previous track
```

## Decorations

Decorations add visual markers to the content:

### Highlight

```dart
await flureadium.applyDecorations('highlights', [
  ReaderDecoration(
    id: 'highlight-1',
    locator: selectedLocator,
    style: ReaderDecorationStyle(
      style: DecorationStyle.highlight,
      tint: Color(0xFFFFFF00),  // Yellow
    ),
  ),
]);
```

### Underline

```dart
await flureadium.applyDecorations('bookmarks', [
  ReaderDecoration(
    id: 'bookmark-1',
    locator: bookmarkLocator,
    style: ReaderDecorationStyle(
      style: DecorationStyle.underline,
      tint: Color(0xFF0000FF),  // Blue
    ),
  ),
]);
```

## Preferences

Customize the reader appearance and behavior.

### EPUB Preferences

```dart
EPUBPreferences(
  fontFamily: 'Georgia',        // Font name
  fontSize: 120,                // 120 = 1.2em (120%)
  fontWeight: 400,              // Normal weight
  verticalScroll: false,        // Paginated mode
  backgroundColor: Color(...),  // Page background
  textColor: Color(...),        // Text color
  pageMargins: 0.1,             // 10% margins
)
```

### TTS Preferences

```dart
TTSPreferences(
  speed: 1.2,                   // 20% faster
  pitch: 1.0,                   // Normal pitch
  voiceIdentifier: 'com.apple.voice.compact.en-US.Samantha',
  languageOverride: 'en-US',
)
```

### Audio Preferences

```dart
AudioPreferences(
  volume: 1.0,                  // Full volume
  speed: 1.5,                   // 1.5x speed
  pitch: 1.0,                   // Normal pitch
  seekInterval: 30,             // Skip 30 seconds
  allowExternalSeeking: true,   // Allow system controls
)
```

## Event Streams

Real-time updates from the reader:

```dart
// Reading position changes
flureadium.onTextLocatorChanged.listen((locator) {
  print('Position: ${locator.locations?.totalProgression}');
});

// Playback state (TTS/audiobook)
flureadium.onTimebasedPlayerStateChanged.listen((state) {
  print('State: ${state.state}');
  print('Current: ${state.currentOffset}');
  print('Duration: ${state.currentDuration}');
});

// Reader status
flureadium.onReaderStatusChanged.listen((status) {
  if (status == ReadiumReaderStatus.reachedEndOfPublication) {
    print('Finished reading!');
  }
});

// Errors
flureadium.onErrorEvent.listen((error) {
  print('Error: ${error.message}');
});
```

## Next Steps

- [API Reference](../api-reference/) - Detailed API documentation
- [EPUB Reading Guide](../guides/epub-reading.md) - Visual reading tutorial
- [Text-to-Speech Guide](../guides/text-to-speech.md) - TTS integration
