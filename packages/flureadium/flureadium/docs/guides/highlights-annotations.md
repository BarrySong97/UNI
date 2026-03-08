# Highlights and Annotations Guide

This guide covers adding visual decorations like highlights, bookmarks, and annotations to publications.

## Decoration Basics

Decorations are visual markers applied to content. Flureadium supports two decoration styles:

- **Highlight** - Background color overlay
- **Underline** - Underline decoration

## Creating Highlights

### Simple Highlight

```dart
final highlight = ReaderDecoration(
  id: 'highlight-1',
  locator: selectedLocator,
  style: ReaderDecorationStyle(
    style: DecorationStyle.highlight,
    tint: Color(0xFFFFFF00),  // Yellow
  ),
);

await flureadium.applyDecorations('highlights', [highlight]);
```

### Color-Coded Highlights

```dart
enum HighlightColor {
  yellow(Color(0xFFFFFF00), 'Yellow'),
  green(Color(0xFF90EE90), 'Green'),
  blue(Color(0xFF87CEEB), 'Blue'),
  pink(Color(0xFFFFB6C1), 'Pink'),
  orange(Color(0xFFFFD700), 'Orange');

  final Color color;
  final String name;
  const HighlightColor(this.color, this.name);
}

void createHighlight(Locator locator, HighlightColor color) {
  final highlight = ReaderDecoration(
    id: uuid.v4(),
    locator: locator,
    style: ReaderDecorationStyle(
      style: DecorationStyle.highlight,
      tint: color.color,
    ),
  );

  _highlights.add(highlight);
  _applyHighlights();
}
```

## Managing Multiple Decorations

### Grouping by Type

```dart
class DecorationManager {
  final List<ReaderDecoration> _highlights = [];
  final List<ReaderDecoration> _bookmarks = [];
  final List<ReaderDecoration> _notes = [];

  Future<void> addHighlight(Locator locator, Color color) async {
    _highlights.add(ReaderDecoration(
      id: uuid.v4(),
      locator: locator,
      style: ReaderDecorationStyle(
        style: DecorationStyle.highlight,
        tint: color,
      ),
    ));
    await _apply('highlights', _highlights);
  }

  Future<void> addBookmark(Locator locator) async {
    _bookmarks.add(ReaderDecoration(
      id: uuid.v4(),
      locator: locator,
      style: ReaderDecorationStyle(
        style: DecorationStyle.underline,
        tint: Color(0xFFFF0000),
      ),
    ));
    await _apply('bookmarks', _bookmarks);
  }

  Future<void> removeHighlight(String id) async {
    _highlights.removeWhere((h) => h.id == id);
    await _apply('highlights', _highlights);
  }

  Future<void> _apply(String group, List<ReaderDecoration> items) async {
    await flureadium.applyDecorations(group, items);
  }
}
```

### Clearing Decorations

```dart
// Clear all highlights
await flureadium.applyDecorations('highlights', []);

// Clear all bookmarks
await flureadium.applyDecorations('bookmarks', []);

// Clear all decorations
await flureadium.applyDecorations('highlights', []);
await flureadium.applyDecorations('bookmarks', []);
await flureadium.applyDecorations('notes', []);
```

## Bookmarks

### Toggle Bookmark

```dart
class BookmarkManager {
  final List<Bookmark> _bookmarks = [];

  bool isBookmarked(String href) {
    return _bookmarks.any((b) => b.locator.href == href);
  }

  Future<void> toggleBookmark(Locator locator) async {
    final existing = _bookmarks.indexWhere(
      (b) => b.locator.href == locator.href,
    );

    if (existing >= 0) {
      _bookmarks.removeAt(existing);
    } else {
      _bookmarks.add(Bookmark(
        id: uuid.v4(),
        locator: locator,
        created: DateTime.now(),
      ));
    }

    await _applyBookmarks();
  }

  Future<void> _applyBookmarks() async {
    final decorations = _bookmarks.map((b) => ReaderDecoration(
      id: b.id,
      locator: b.locator,
      style: ReaderDecorationStyle(
        style: DecorationStyle.underline,
        tint: Color(0xFFFF0000),
      ),
    )).toList();

    await flureadium.applyDecorations('bookmarks', decorations);
  }
}

class Bookmark {
  final String id;
  final Locator locator;
  final DateTime created;
  String? note;

  Bookmark({
    required this.id,
    required this.locator,
    required this.created,
    this.note,
  });
}
```

### Bookmark List View

```dart
class BookmarkListView extends StatelessWidget {
  final List<Bookmark> bookmarks;
  final Function(Bookmark) onTap;
  final Function(Bookmark) onDelete;

  const BookmarkListView({
    required this.bookmarks,
    required this.onTap,
    required this.onDelete,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: bookmarks.length,
      itemBuilder: (_, index) {
        final bookmark = bookmarks[index];
        return Dismissible(
          key: Key(bookmark.id),
          onDismissed: (_) => onDelete(bookmark),
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.delete, color: Colors.white),
          ),
          child: ListTile(
            leading: Icon(Icons.bookmark),
            title: Text(bookmark.locator.title ?? 'Bookmark'),
            subtitle: Text(
              _formatDate(bookmark.created),
            ),
            onTap: () => onTap(bookmark),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}
```

## Highlight List

### Display All Highlights

```dart
class HighlightListView extends StatelessWidget {
  final List<Highlight> highlights;
  final Function(Highlight) onTap;
  final Function(Highlight) onDelete;
  final Function(Highlight, Color) onColorChange;

  const HighlightListView({
    required this.highlights,
    required this.onTap,
    required this.onDelete,
    required this.onColorChange,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: highlights.length,
      itemBuilder: (_, index) {
        final highlight = highlights[index];
        return Card(
          margin: EdgeInsets.all(8),
          child: InkWell(
            onTap: () => onTap(highlight),
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Color and chapter
                  Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: highlight.color,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          highlight.locator.title ?? 'Unknown',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      PopupMenuButton<Color>(
                        icon: Icon(Icons.palette),
                        onSelected: (color) => onColorChange(highlight, color),
                        itemBuilder: (_) => HighlightColor.values.map((c) {
                          return PopupMenuItem(
                            value: c.color,
                            child: Row(
                              children: [
                                Container(
                                  width: 16,
                                  height: 16,
                                  color: c.color,
                                ),
                                SizedBox(width: 8),
                                Text(c.name),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () => onDelete(highlight),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  // Highlighted text
                  if (highlight.locator.text?.highlight != null)
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: highlight.color.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        highlight.locator.text!.highlight!,
                        style: TextStyle(fontStyle: FontStyle.italic),
                      ),
                    ),
                  // Note
                  if (highlight.note != null)
                    Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(highlight.note!),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class Highlight {
  final String id;
  final Locator locator;
  Color color;
  String? note;
  final DateTime created;

  Highlight({
    required this.id,
    required this.locator,
    required this.color,
    required this.created,
    this.note,
  });
}
```

## Adding Notes to Highlights

```dart
class AnnotationManager {
  final List<Annotation> _annotations = [];

  Future<void> addAnnotation(Locator locator, String note, Color color) async {
    _annotations.add(Annotation(
      id: uuid.v4(),
      locator: locator,
      note: note,
      color: color,
      created: DateTime.now(),
    ));
    await _apply();
  }

  Future<void> updateNote(String id, String note) async {
    final index = _annotations.indexWhere((a) => a.id == id);
    if (index >= 0) {
      _annotations[index].note = note;
      // Decorations don't need to be re-applied for note changes
    }
  }

  Future<void> _apply() async {
    final decorations = _annotations.map((a) => ReaderDecoration(
      id: a.id,
      locator: a.locator,
      style: ReaderDecorationStyle(
        style: DecorationStyle.highlight,
        tint: a.color,
      ),
    )).toList();

    await flureadium.applyDecorations('annotations', decorations);
  }
}

class Annotation {
  final String id;
  final Locator locator;
  String note;
  Color color;
  final DateTime created;
  DateTime modified;

  Annotation({
    required this.id,
    required this.locator,
    required this.note,
    required this.color,
    required this.created,
  }) : modified = created;
}
```

## Search Result Highlighting

```dart
class SearchManager {
  Future<void> highlightResults(List<Locator> results) async {
    final decorations = results.mapIndexed((index, locator) {
      return ReaderDecoration(
        id: 'search-$index',
        locator: locator,
        style: ReaderDecorationStyle(
          style: DecorationStyle.highlight,
          tint: Color(0xFFFFD700),  // Gold
        ),
      );
    }).toList();

    await flureadium.applyDecorations('search', decorations);
  }

  Future<void> clearResults() async {
    await flureadium.applyDecorations('search', []);
  }
}
```

## Persisting Decorations

### Save to Storage

```dart
class DecorationStorage {
  Future<void> saveHighlights(
    String bookId,
    List<Highlight> highlights,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final json = highlights.map((h) => {
      'id': h.id,
      'locator': h.locator.toJson(),
      'color': h.color.value,
      'note': h.note,
      'created': h.created.toIso8601String(),
    }).toList();

    await prefs.setString('highlights_$bookId', jsonEncode(json));
  }

  Future<List<Highlight>> loadHighlights(String bookId) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('highlights_$bookId');
    if (jsonStr == null) return [];

    final List<dynamic> json = jsonDecode(jsonStr);
    return json.map((j) => Highlight(
      id: j['id'],
      locator: Locator.fromJson(j['locator'])!,
      color: Color(j['color']),
      note: j['note'],
      created: DateTime.parse(j['created']),
    )).toList();
  }
}
```

### Load on Book Open

```dart
Future<void> _openBook(String path) async {
  final pub = await flureadium.openPublication(path);

  // Load saved decorations
  final storage = DecorationStorage();
  final highlights = await storage.loadHighlights(pub.identifier);
  final bookmarks = await storage.loadBookmarks(pub.identifier);

  // Apply to reader
  await flureadium.applyDecorations('highlights',
    highlights.map((h) => ReaderDecoration(
      id: h.id,
      locator: h.locator,
      style: ReaderDecorationStyle(
        style: DecorationStyle.highlight,
        tint: h.color,
      ),
    )).toList(),
  );

  await flureadium.applyDecorations('bookmarks',
    bookmarks.map((b) => ReaderDecoration(
      id: b.id,
      locator: b.locator,
      style: ReaderDecorationStyle(
        style: DecorationStyle.underline,
        tint: Color(0xFFFF0000),
      ),
    )).toList(),
  );
}
```

## Complete Annotation System

```dart
class AnnotationSystem {
  final _highlights = <Highlight>[];
  final _bookmarks = <Bookmark>[];
  final _storage = DecorationStorage();

  String? _currentBookId;

  Future<void> loadForBook(String bookId) async {
    _currentBookId = bookId;
    _highlights.clear();
    _bookmarks.clear();

    _highlights.addAll(await _storage.loadHighlights(bookId));
    _bookmarks.addAll(await _storage.loadBookmarks(bookId));

    await _applyAll();
  }

  Future<void> addHighlight(Locator locator, Color color, {String? note}) async {
    final highlight = Highlight(
      id: uuid.v4(),
      locator: locator,
      color: color,
      note: note,
      created: DateTime.now(),
    );

    _highlights.add(highlight);
    await _applyHighlights();
    await _save();
  }

  Future<void> toggleBookmark(Locator locator) async {
    final existing = _bookmarks.indexWhere(
      (b) => b.locator.href == locator.href,
    );

    if (existing >= 0) {
      _bookmarks.removeAt(existing);
    } else {
      _bookmarks.add(Bookmark(
        id: uuid.v4(),
        locator: locator,
        created: DateTime.now(),
      ));
    }

    await _applyBookmarks();
    await _save();
  }

  Future<void> deleteHighlight(String id) async {
    _highlights.removeWhere((h) => h.id == id);
    await _applyHighlights();
    await _save();
  }

  Future<void> deleteBookmark(String id) async {
    _bookmarks.removeWhere((b) => b.id == id);
    await _applyBookmarks();
    await _save();
  }

  Future<void> _applyAll() async {
    await _applyHighlights();
    await _applyBookmarks();
  }

  Future<void> _applyHighlights() async {
    await flureadium.applyDecorations('highlights',
      _highlights.map((h) => ReaderDecoration(
        id: h.id,
        locator: h.locator,
        style: ReaderDecorationStyle(
          style: DecorationStyle.highlight,
          tint: h.color,
        ),
      )).toList(),
    );
  }

  Future<void> _applyBookmarks() async {
    await flureadium.applyDecorations('bookmarks',
      _bookmarks.map((b) => ReaderDecoration(
        id: b.id,
        locator: b.locator,
        style: ReaderDecorationStyle(
          style: DecorationStyle.underline,
          tint: Color(0xFFFF0000),
        ),
      )).toList(),
    );
  }

  Future<void> _save() async {
    if (_currentBookId != null) {
      await _storage.saveHighlights(_currentBookId!, _highlights);
      await _storage.saveBookmarks(_currentBookId!, _bookmarks);
    }
  }

  List<Highlight> get highlights => List.unmodifiable(_highlights);
  List<Bookmark> get bookmarks => List.unmodifiable(_bookmarks);
}
```

## See Also

- [Decorations Reference](../api-reference/decorations.md) - API documentation
- [Locator Reference](../api-reference/locator.md) - Position tracking
- [Saving Progress Guide](saving-progress.md) - Persistence patterns
