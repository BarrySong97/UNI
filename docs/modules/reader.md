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
- Audio/translation capabilities
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
        kp_item_builder.dart        # RenderNode children → K-P item sequence (uses WidthCache)
        width_cache.dart            # Chapter-scoped cache for space and word widths per TextStyle
        paragraph_prepare_cache.dart # Caches pre-built K-P item sequences for repeated paragraph layouts
    selection/
      page_hit_test.dart              # Hit-testing, selection rects, text extraction
      cross_page_selection.dart       # BookPosition, CrossPageSelection (multi-page model)
    data/
      chapter_data_source.dart      # Abstract interface for chapter loading
      cached_chapter_data_source.dart # Reads pre-parsed JSON from cache dir
      chapter_json_bridge.dart      # Legacy: direct Rust CLI bridge (unused)
    epub_preparse_service.dart      # Calls Rust CLI --batch-export at import time
  stores/reader/
    reader_store.dart               # ChangeNotifier: pagination, navigation, progress
    reader_store_manager.dart       # LRU cache of ReaderStore instances per book ID
    page_navigation_strategy.dart   # Strategy pattern: phone (single-page) vs tablet (dual-page) navigation
  pages/reader/
    reader_page.dart                # Main page: CustomPaint + GestureDetector
    reader_coordinate_helper.dart   # Coordinate transforms: phone vs tablet screen↔content mapping
    widgets/
      reader_canvas_painter.dart    # CustomPainter rendering PageLayout
      reader_controls_overlay.dart  # Bottom icon toolbar + inline panel toggle (AnimatedSize)
      reader_font_panel.dart        # Font size, margin, line spacing, font family picker
      reader_toc_panel.dart         # Inline TOC panel with scrollable chapter list
      reader_progress_panel.dart    # Inline progress slider panel
      reader_theme_panel.dart       # Inline theme color swatch panel
      reader_explain_sheet.dart     # AI explain bottom sheet (word header + Markdown response)
      reader_selection_handle.dart  # Draggable teardrop selection handle widget
```

## Core Flow

### Pagination Algorithm

1. Compute `contentWidth` and `contentHeight` from viewport - page padding - safe areas
2. Walk each `RenderNode` through `LayoutContext` (tracks `cursorY`, current page, margin state)
3. For each paragraph:
   - Apply CSS margin collapsing (max of adjacent top/bottom margins)
   - **Smart justify override**: paragraphs with `TextAlign.left` (the default when EPUB CSS omits `text-align`) are automatically overridden to `TextAlign.justify` only when `_shouldJustify()` returns true — i.e. the paragraph has no `LineBreakNode` children (ruling out ISBN metadata, addresses, poetry) and its text fills at least ~1.5 lines (ruling out short TOC entries and titles). This matches the behaviour of mainstream reader apps (Apple Books, Kindle) for body text while preserving natural spacing for structured content. Headings and explicitly-centered/right-aligned text are never overridden.
   - **Justified text (Knuth-Plass path)**: attempted first (greedy TextPainter is only created on K-P fallback). Convert children to Box/Glue/Penalty items (word measurement via chapter-scoped `WidthCache`) using a mixed tokenizer: space-delimited Latin text stays word-based, while no-space CJK runs are split into per-character boxes with breakable zero-width glue/soft penalties. Run K-P solver (ported from tex-linebreak) to find optimal breakpoints minimising total demerits. The solver now follows tex-linebreak's two-pass helper strategy: first pass uses `maxAdjustmentRatio=1` to avoid loose lines (especially for English), and only when that fails does it retry with relaxed limits. Solver includes Restriction-1 guarded pruning, look-ahead to next box, and emergency breaks. Then run `positionItems()` and render each box/hyphen fragment at exact x offsets (no uniform `wordSpacing` approximation). Non-last lines get a per-line right-edge gap correction to compensate for sub-pixel measurement drift. Falls back to greedy if both solver passes fail or the result is a single line (nothing to justify). Additionally, `positionItems()` caps the stretch ratio for non-last lines at 2.0 (`_maxVisualRatio`) — lines with few words won't get excessively wide word spacing; they simply won't fill the full width, which looks far better than huge gaps.
   - **Soft hyphen (`\u00AD`) support in K-P items**: inside word tokens, soft hyphen is treated as a discretionary breakpoint (`KPPenalty`) with visible `-` width only when that breakpoint is selected. If no break occurs, the soft hyphen is invisible and contributes no width.
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
- `text-indent`: normalized to no indent in Flutter layout to keep first-line alignment consistent across mixed EPUB content
- `margin-left` (CSS): normalized to no indent for body text (paragraphs and headings); structural indentation from list nesting and blockquotes is preserved via the internal `nestingIndentEm` mechanism

### Performance Optimizations

- **Cross-chapter `WidthCache`**: A single `WidthCache` instance is shared across all chapters within the same `ReaderStore` session (cleared only when layout-affecting preferences change). Caches both space widths and word widths keyed by `(style, word)`. Repeated words like "the", "and" are measured only once across all chapters, eliminating redundant TextPainter creation. Subsequent chapter paginations are 10-30% faster due to cache hits on common vocabulary.
- **Paragraph prepare cache**: K-P item sequences are cached per paragraph signature (text/style/layout inputs) and reused across repeated pagination calls. This avoids rebuilding token/script-run segmentation and Box/Glue/Penalty sequences for unchanged paragraphs.
- **K-P solver look-ahead hoisting**: The look-ahead loop (computing `widthToNextBox/shrinkToNextBox/stretchToNextBox`) depends only on breakpoint position `b`, not on active node `a`. Hoisted above the active-node loop to avoid redundant O(active × scan) work per breakpoint.
- **Deferred greedy TextPainter**: For justified paragraphs, the K-P path is attempted first. The greedy `TextSpan` + `TextPainter` are only created if K-P fails, avoiding wasted native layout calls on the happy path.
- **Shared style computation**: `TextSpanBuilder.styleForTextNode()` is the single source of truth for `TextNode → TextStyle` conversion, used by both the greedy path and K-P item builder.
- **Async page-count computation**: `_computeAllPageCounts()` yields to the event loop between chapters (`await Future.delayed(Duration.zero)`), has an abort guard (stops if book/preferences change mid-computation), and uses a lightweight `_pageCountCache` that survives across calls without storing full pagination data.
- **Deferred adjacent chapter prefetching**: After loading a chapter, adjacent chapters (next and previous) are prefetched in the background with a 500ms delay. The delay ensures the first frame renders before heavy background pagination starts. Prefetches are sequenced (not concurrent) to avoid back-to-back pressure. Uses `prefetchOnly` flag to avoid mutating current pagination state.
- **Robust TOC href matching**: TOC→spine mapping uses a shared href matcher with normalized-path priority and safe fallback matching (full normalized path → suffix path → unique filename). This handles real-world EPUB path variations (leading `/`, `./`, and `#fragment` differences) so chapter title/highlight/navigation stay aligned with the actual content page.
- **Persistent page count cache**: After `_computeAllPageCounts()` completes, the per-chapter page counts are serialized to a JSON blob (`pageCountsJson` column on `reading_progress` table, migration v11) alongside the raw layout parameters (viewport size + 6 preference values). On subsequent `openBook()`, if the stored parameters match the current viewport and preferences, page counts are restored instantly from DB — skipping the expensive full-book pagination entirely. Uses raw parameter comparison instead of `Object.hash` because hash seeds are randomized per Dart VM invocation.
- **`pageCountOnly` fast pagination mode**: When computing page counts for progress display, `paginate(pageCountOnly: true)` skips the K-P justified layout path (all paragraphs use a single greedy `TextPainter.layout()` instead of per-word measurement + solver + per-fragment painters), skips `LayoutElement` allocation (only tracks a page counter), and skips list marker measurement + positioning. Greedy and K-P produce the same line count ±0-1 per paragraph, so page count accuracy is preserved. Reduces page-count computation time by ~60-75%.
- **K-P solver data structure optimizations**: The active node collection uses `List<_Node>` instead of `Set<_Node>` (avoids iterator/hashCode overhead for the typical 5-15 node set). The `feasible` intermediate list is eliminated — the best feasible node is tracked inline during the active-node loop. The `toRemove` list is eliminated — nodes are removed in-place via `removeAt` during reverse iteration. `hasNegativeValues` is computed once with an early-exit loop instead of `items.any()` with closures.
- **Data source warm-up**: `CachedChapterDataSource.warmUp()` pre-reads `book.json` and the first chapter JSON into memory. Called fire-and-forget in `ReaderEntryService` before `Navigator.push()`, so file I/O overlaps with the route transition animation (~300ms). When `ReaderStore.openBook()` calls `loadBook()`/`loadChapter()`, data is already in memory.
- **ReaderStore LRU caching**: `ReaderStoreManager` maintains an LRU cache of up to 2 `ReaderStore` instances keyed by book ID. When the user re-opens a book, the existing store (with all in-memory pagination caches, decoded images, and TextPainters) is reused instantly. `openBook()` detects same-book re-opens via a fast path and skips the full load pipeline. Stores evicted from the LRU cache are disposed to free memory.
- **Deferred text painter for K-P fragments**: In Knuth-Plass paragraph layout, pagination stores `(text, style)` on `LayoutElement` and creates `TextPainter` lazily via `ensurePainter()` only when rendering or hit-testing needs it. This removes large eager `TextPainter` allocation spikes during pagination.
- **Async chunked pagination**: `ReaderLayoutEngine.paginateAsync()` yields to the event loop every few nodes. `ReaderStore` uses the async path for chapter load and whole-book page-count computation, so loading indicators and UI interactions remain responsive during pagination.
- **Stale async result guard**: `ReaderStore` uses a monotonic request token to ignore outdated async pagination results, preventing race conditions when chapter/viewport/preferences change rapidly.

### Cache Invalidation

Cache key = `(chapterIndex, viewportSize, preferencesLayoutHash)`

Invalidated by: font size/family change, line height change, page margin change, screen rotation

## Key State & Data

- `ReaderStore` (ChangeNotifier): manages book, chapters, pagination cache, current position, preferences
  - Display chapter resolution: when current spine chapter is not TOC-addressable (e.g. interstitial image/title pages), chapter title and TOC highlight are resolved to the nearest previous TOC chapter so labels stay aligned with reading context.
- Reader progress semantics in `ReaderStore`:
  - `bookPositionPercent`: position-based percent (first page = 0%, last page = 100%) for in-reader UI display and slider value.
  - `bookReadPercent`: read-based percent (first page > 0%, last page = 100%) for persistence/statistics.
- `ReadingTimeTracker`: tracks active reading time only while Reader is foregrounded and the user has interacted within the last 30 seconds; flushes whole seconds to DB on a timer, on background, and on dispose.
- `ReaderPreferences`: baseFontSizePx, fontFamily, pageHorizontalPaddingPx, pageVerticalPaddingPx, lineHeightMultiplier, paragraphSpacingMultiplier, theme
- `ReadingProgressEntity(bookId, locatorJson, percent, updatedAt, prefsJson, pageCountsJson)`: locatorJson stores `{"chapterIndex": N, "pageIndex": M}`, `percent` stores read-based progress (`bookReadPercent`), prefsJson stores per-book ReaderPreferences as JSON, pageCountsJson stores persisted page count cache with layout parameter validation
- `ChapterPagination`: cached per chapter, invalidated on layout parameter changes
- `BookStatsTable(book_id, explain_count, phonetics_count, reading_time_seconds)`: per-book counters plus cumulative reading time in whole seconds (DB v16)
- `ReadingTimeDailyTable(book_id, date_key, duration_seconds)`: per-book per-day aggregated reading time used by Shelf monthly statistics (DB v16)

## Interaction & Error Handling

- Content area avoids system status bar and bottom gesture area (safe area insets)
- Horizontal swipe page turning: drag left/right to preview next/previous page with follow-the-finger animation; on release, completes page turn (>25% screen width or velocity >500px/s) or snaps back. Rubber-band effect at first/last page of book. Adjacent chapters prefetched for smooth cross-chapter swipe.
- Swipe transition stability: during drag + settle animation, both current spread and adjacent spread use frozen page snapshots (instead of live store pages). This prevents one-frame blank/overlap artifacts when content type changes abruptly (e.g. image-only page ↔ text-only page). At animation completion, drag offset snaps to exact ±screen width before page-state swap, then resets on the next frame.
- Tap left 30% = previous page, right 30% = next page, center 40% = toggle controls (tap and swipe coexist). Tap navigation reuses the swipe animation path (snapshotted pages + two-frame swap) to avoid one-frame flicker when switching between very different page types (e.g. image-only ↔ text-only).
- Text selection via long-press: long-press to select a word, drag to extend. After release, two draggable handles appear for fine adjustment. Tap anywhere to clear selection. Selection is cleared on non-selection page navigation.
- Cross-page selection: dragging a handle to the screen edge (40px zone) for 300ms triggers an animated page turn. The selection extends onto the new page with the anchor end preserved. A thin edge indicator shows when selection continues beyond the visible page. Supports multi-page and cross-chapter selection. Text extraction concatenates across all pages in the selection range.
- AI Explain: selecting text shows a tooltip with "Explain" button. Tapping it opens a bottom sheet that calls an OpenAI-compatible LLM to explain the passage. For single words/phrases: shows the word in large bold text with the containing sentence (word highlighted in bold). For longer selections: shows an italic text preview. Below is the AI explanation rendered as Markdown (no chat input). Prompt detail levels: Brief (1-2 sentences), Balanced (short paragraph, default), Detailed (thorough but focused). Uses `ExplainAiService` backed by Genkit + OpenAI plugin. API credentials configured in Settings page via `AiSettingsService` (SharedPreferences). Each tap on Explain increments per-book `explain_count` in `book_stats` table.
- Phonetics lookup count: each tap on the "Phonetics" tooltip button increments per-book `phonetics_count` in `book_stats` table (DB v15).
- Reading time tracking: opening Reader counts as the initial interaction. While the page remains in the foreground, reading time continues only if the user has interacted in the last 30 seconds (tap, drag, long-press, selection handle drag, etc.). Going to background immediately flushes and pauses tracking; returning to foreground requires a new interaction before time resumes. Time is stored as whole seconds and aggregated by local calendar day.
- Controls overlay with slide animation: top bar slides down (back + more menu), bottom icon toolbar slides up (5 buttons: TOC, annotation, progress, theme, font). Each button toggles an inline panel above the toolbar with AnimatedSize expand/collapse. Only one panel visible at a time; tapping a different button switches directly.
- Font settings panel (toggled by "A" button): A-/A+ font size control, margin presets (SM/Margin/LG), line spacing presets (Tight/Spacing/Loose), font family picker with curated system fonts
- Preference changes keep controls overlay visible (no close on setting change)
- TOC sheet: scrollable chapter list with current chapter highlighted
- Cross-chapter navigation: next page on last page advances to next chapter, previous on first page goes back
- Error state shows message + "Go Back" button
- Loading state shows themed circular progress indicator
- Font size range: 12-32px
- Theme options: Light (white bg), Sepia (warm bg), Mint (soft green bg), Rose (soft pink bg), Dusk (deep blue-gray bg, dark), Dark (dark bg), Night (pure black AMOLED bg, dark) — selectable via inline theme panel with color swatches. Dark themes (`isDark` flag) automatically adjust status bar style, controls bar color, and code block backgrounds.

## Acceptance Criteria

- Reader page renders EPUB text content via Canvas (CustomPainter)
- Rich text (bold, italic, underline, headings, lists, tables) renders correctly
- Pagination correctly splits long paragraphs at line boundaries
- Tap navigation (left/center/right zones) works
- Horizontal swipe page turning works with smooth animation and cross-chapter support
- Text selection works: long-press selects word, drag extends, handles adjust range
- Cross-page selection works: handle drag to screen edge triggers page turn, selection spans multiple pages
- AI Explain: selecting text → tap Explain → bottom sheet shows word header (word + sentence) or text preview → streams AI explanation as Markdown. Word mode bolds the selected word in the containing sentence. Unconfigured API key shows SnackBar prompt.
- Font size adjustment causes repagination with correct results
- Theme switching (light/sepia/mint/rose/dusk/dark/night) applies immediately
- Reading progress persists across app restarts
- Reader preferences persist per book (font size, font family, margins, line spacing, theme)
- Chapter navigation (next/previous) works
- TOC sheet lists chapters and supports jump-to-chapter
- Tapping Explain increments `explain_count` in `book_stats` for the current book
- Tapping Phonetics increments `phonetics_count` in `book_stats` for the current book
- Active reading time is recorded into `book_stats.reading_time_seconds` and `reading_time_daily`
- `flutter analyze` passes with no issues in reader code

## Non-Goals

- Highlighting in Canvas reader (future work)
- Audio/translation
- TXT/PDF format support
- flutter_rust_bridge FFI (Phase 2, currently using JSON CLI bridge)
- Full image rendering from EPUB (placeholder only)
