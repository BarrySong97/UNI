# Module: reader (Canvas-based EPUB Reader)

> **Status**: Rebuilt using Canvas rendering + Rust EPUB parser. Replaces the previous Readium-based reader.

## Module Purpose

Provides an immersive book reading experience using Canvas-based rendering. The Rust EPUB parser extracts content into a `RenderNode` tree, which Flutter's `TextPainter` + `CustomPainter` pipeline paginates and renders into fixed-size pages. Supports tap-to-navigate, font/theme preferences, and reading progress persistence.

## Boundary

### In

- Open books and restore last reading position (chapter + page index)
- Canvas-based text rendering via `CustomPainter` + `TextPainter`
- Pagination engine: splits `RenderNode` content into fixed-size pages
- Rich text: bold, italic, underline, strikethrough, font sizes, colors
- Block types: paragraphs, headings (h1-h6), lists, tables, blockquotes, code blocks, images (placeholder), horizontal rules
- Paragraph-first-line alignment normalization (no mixed first-line indent per paragraph)
- List marker mapping for common list-style types (disc/circle/square/decimal/lower-alpha/upper-alpha/lower-roman/upper-roman)
- Tap zones: left 30% = previous page, right 30% = next page, center = toggle controls
- Controls overlay: bottom icon toolbar (TOC, annotation, progress, theme cycle, font settings "A")
- Font settings panel: font size +/-, margin (small/medium/large), line spacing (tight/medium/loose), font family picker
- Font family picker: curated system font list (iOS / Android), preview in-font, system default option
- TOC bottom sheet with chapter list and current chapter highlight
- Reading preferences: font size, font family, page margins, line height, paragraph spacing, theme
- Progress persistence via `ReadingProgressEntity` (chapter index + page index)
- Multi-chapter navigation with progress saving

### Out

- Highlighting (not yet implemented in Canvas reader)
- Audio/AI/translation capabilities
- TXT/PDF format support
- flutter_rust_bridge FFI integration (Phase 2)
- Image rendering from base64 data (placeholder only for now)

## Architecture

```
Rust CLI (epub_parser)           Flutter Layout Engine               Canvas Renderer
EPUB → parse_chapter()           RenderNode[] → paginate()           PageLayout → paint()
     → JSON stdout               ↓ Justified? → Knuth-Plass         CustomPainter draws
                                  ↓   Items → Solver → Breakpoints   text/bg/borders
                                  ↓   positionItems() → x offsets
                                  ↓ Else → TextPainter greedy
                                  → PageLayout[]
```

### Data Flow

1. **Import time**: `EpubPreparseService` calls Rust CLI `--batch-export` to pre-parse the entire EPUB into cached JSON files (`book.json` + `chapter_N.json` per spine entry)
2. **Open book**: `ReaderEntryService` builds `CachedChapterDataSource` pointing to the cache directory, opens `ReaderPage` with `ReaderStore`
3. **ReaderStore** loads `book.json` for metadata/TOC/chapter count, then loads individual `chapter_N.json` on demand
4. **Layout Engine** walks `RenderNode` tree, measures text with `TextPainter`, splits into `PageLayout[]`
   - For oversized table rows that exceed page height, applies continuation-row fallback pagination to avoid visual clipping
   - Pre-decodes images recursively from nested node trees (list/table/blockquote/code children)
5. **Canvas Painter** draws each `LayoutElement` (text, backgrounds, borders) onto `Canvas`
6. **ReaderPage** wraps `CustomPaint` in `GestureDetector` for navigation

## File Structure

```
lib/
  services/reader/
    models/
      render_node.dart              # Sealed class hierarchy mirroring Rust model.rs
      parsed_chapter.dart           # ParsedChapter, ParsedBook, TocEntry
      reader_preferences.dart       # ReaderPreferences, ReaderTheme enum
      page_layout.dart              # LayoutElement, PageLayout, ChapterPagination
    layout/
      reader_layout_engine.dart     # Main paginator: walks nodes → PageLayout[]
      paragraph_layouter.dart       # Paragraph measurement + cross-page line splitting
      text_span_builder.dart        # RenderNode children → TextSpan tree
      layout_context.dart           # Mutable context (cursorY, currentPage, margin state)
      knuth_plass/
        kp_items.dart               # Box/Glue/Penalty sealed classes for K-P algorithm
        kp_solver.dart              # K-P solver (ported from tex-linebreak) + adjustmentRatios()/positionItems()
        kp_item_builder.dart        # RenderNode children → K-P item sequence (TextPainter reuse)
        width_cache.dart            # Structural-key space width cache per TextStyle
    data/
      chapter_data_source.dart      # Abstract interface for chapter loading
      cached_chapter_data_source.dart # Reads pre-parsed JSON from cache dir
      chapter_json_bridge.dart      # Legacy: direct Rust CLI bridge (unused)
    epub_preparse_service.dart      # Calls Rust CLI --batch-export at import time
  stores/reader/
    reader_store.dart               # ChangeNotifier: pagination, navigation, progress
  pages/reader/
    reader_page.dart                # Main page: CustomPaint + GestureDetector
    widgets/
      reader_canvas_painter.dart    # CustomPainter rendering PageLayout
      reader_controls_overlay.dart  # Bottom icon toolbar + font panel toggle
      reader_font_panel.dart        # Font size, margin, line spacing, font family picker
      reader_toc_sheet.dart         # TOC bottom sheet
```

## Core Flow

### Pagination Algorithm

1. Compute `contentWidth` and `contentHeight` from viewport - page padding - safe areas
2. Walk each `RenderNode` through `LayoutContext` (tracks `cursorY`, current page, margin state)
3. For each paragraph:
   - Apply CSS margin collapsing (max of adjacent top/bottom margins)
   - **Smart justify override**: paragraphs with `TextAlign.left` (the default when EPUB CSS omits `text-align`) are automatically overridden to `TextAlign.justify` only when `_shouldJustify()` returns true — i.e. the paragraph has no `LineBreakNode` children (ruling out ISBN metadata, addresses, poetry) and its text fills at least ~1.5 lines (ruling out short TOC entries and titles). This matches the behaviour of mainstream reader apps (Apple Books, Kindle) for body text while preserving natural spacing for structured content. Headings and explicitly-centered/right-aligned text are never overridden.
   - **Justified text (Knuth-Plass path)**: convert children to Box/Glue/Penalty items (word measurement via reused `TextPainter` stored on each `KPBox`) using a mixed tokenizer: space-delimited Latin text stays word-based, while no-space CJK runs are split into per-character boxes with breakable zero-width glue/soft penalties. Run K-P solver (ported from tex-linebreak) to find optimal breakpoints minimising total demerits. The solver now follows tex-linebreak's two-pass helper strategy: first pass uses `maxAdjustmentRatio=1` to avoid loose lines (especially for English), and only when that fails does it retry with relaxed limits. Solver includes Restriction-1 guarded pruning, look-ahead to next box, and emergency breaks. Then run `positionItems()` and render each box/hyphen fragment at exact x offsets (no uniform `wordSpacing` approximation). Non-last lines get a per-line right-edge gap correction to compensate for sub-pixel measurement drift. Falls back to greedy if both solver passes fail or the result is a single line (nothing to justify). Additionally, `positionItems()` caps the stretch ratio for non-last lines at 2.0 (`_maxVisualRatio`) — lines with few words won't get excessively wide word spacing; they simply won't fill the full width, which looks far better than huge gaps.
   - **Non-justified text (greedy path)**: Build `TextSpan` from children, measure with `TextPainter`
   - If fits on current page → place as single `LayoutElement`
   - If overflows → split at line boundary using `computeLineMetrics()` + `getPositionForOffset()`, place first part, start new page, recursively layout remainder
4. Heading: widow prevention (push to next page if < 2 lines of space would follow)
5. Table: equal-width columns, per-row height = max cell height, cell backgrounds/borders
   - Oversized row fallback: split cell text into continuation chunks across pages when a single row is taller than page content height
6. Output: `ChapterPagination` containing `List<PageLayout>`

### Fonts (em → px)

- Rust normalizes all CSS font sizes to `em` units
- Flutter converts: `pixelSize = fontSizeEm × baseFontSizePx` (default 18.0)
- Heading defaults when CSS doesn't specify: h1=2.0em, h2=1.5em, h3=1.25em, h4=1.125em, h5=1.0em, h6=0.875em
- All headings rendered bold

### Margins

- Page padding: `contentWidth = viewport.width - 2 × pageHorizontalPaddingPx`
- Paragraph margins from CSS em values, with CSS-style margin collapsing
- First element on page: top margin suppressed
- Line height: CSS override or user preference (default 1.6)
- `text-indent`: currently normalized to no indent in Flutter layout to keep first-line alignment consistent across mixed EPUB content

### Cache Invalidation

Cache key = `(chapterIndex, viewportSize, preferencesLayoutHash)`

Invalidated by: font size/family change, line height change, page margin change, screen rotation

## Key State & Data

- `ReaderStore` (ChangeNotifier): manages book, chapters, pagination cache, current position, preferences
- `ReaderPreferences`: baseFontSizePx, fontFamily, pageHorizontalPaddingPx, pageVerticalPaddingPx, lineHeightMultiplier, paragraphSpacingMultiplier, theme
- `ReadingProgressEntity(bookId, locatorJson, percent, updatedAt, prefsJson)`: locatorJson stores `{"chapterIndex": N, "pageIndex": M}`, prefsJson stores per-book ReaderPreferences as JSON
- `ChapterPagination`: cached per chapter, invalidated on layout parameter changes

## Interaction & Error Handling

- Content area avoids system status bar and bottom gesture area (safe area insets)
- Tap left 30% = previous page, right 30% = next page, center 40% = toggle controls
- Controls overlay with slide animation: top bar slides down (back + more menu), bottom icon toolbar slides up (5 buttons: TOC, annotation, progress, theme, font)
- Font settings panel (toggled by "A" button): A-/A+ font size control, margin presets (SM/Margin/LG), line spacing presets (Tight/Spacing/Loose), font family picker with curated system fonts
- Preference changes keep controls overlay visible (no close on setting change)
- TOC sheet: scrollable chapter list with current chapter highlighted
- Cross-chapter navigation: next page on last page advances to next chapter, previous on first page goes back
- Error state shows message + "Go Back" button
- Loading state shows themed circular progress indicator
- Font size range: 12-32px
- Theme options: Light (white bg), Sepia (warm bg), Dark (dark bg)

## Acceptance Criteria

- Reader page renders EPUB text content via Canvas (CustomPainter)
- Rich text (bold, italic, underline, headings, lists, tables) renders correctly
- Pagination correctly splits long paragraphs at line boundaries
- Tap navigation (left/center/right zones) works
- Font size adjustment causes repagination with correct results
- Theme switching (light/sepia/dark) applies immediately
- Reading progress persists across app restarts
- Reader preferences persist per book (font size, font family, margins, line spacing, theme)
- Chapter navigation (next/previous) works
- TOC sheet lists chapters and supports jump-to-chapter
- `flutter analyze` passes with no issues in reader code

## Non-Goals

- Highlighting in Canvas reader (future work)
- Audio/AI/translation
- TXT/PDF format support
- Real reading time tracking
- flutter_rust_bridge FFI (Phase 2, currently using JSON CLI bridge)
- Full image rendering from EPUB (placeholder only)
