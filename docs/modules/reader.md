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
  pages/reader/
    reader_page.dart                # Main page: CustomPaint + GestureDetector
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

### Performance Optimizations

- **Chapter-scoped `WidthCache`**: A single `WidthCache` instance is shared across all paragraphs in a chapter via `LayoutContext`. Caches both space widths and word widths keyed by `(style, word)`. Repeated words like "the", "and" are measured only once per chapter, eliminating the TextPainter-per-word explosion.
- **K-P solver look-ahead hoisting**: The look-ahead loop (computing `widthToNextBox/shrinkToNextBox/stretchToNextBox`) depends only on breakpoint position `b`, not on active node `a`. Hoisted above the active-node loop to avoid redundant O(active × scan) work per breakpoint.
- **Deferred greedy TextPainter**: For justified paragraphs, the K-P path is attempted first. The greedy `TextSpan` + `TextPainter` are only created if K-P fails, avoiding wasted native layout calls on the happy path.
- **Shared style computation**: `TextSpanBuilder.styleForTextNode()` is the single source of truth for `TextNode → TextStyle` conversion, used by both the greedy path and K-P item builder.
- **Async page-count computation**: `_computeAllPageCounts()` yields to the event loop between chapters (`await Future.delayed(Duration.zero)`), has an abort guard (stops if book/preferences change mid-computation), and uses a lightweight `_pageCountCache` that survives across calls without storing full pagination data.
- **Adjacent chapter prefetching**: After loading a chapter, the next chapter is prefetched fire-and-forget in the background. Uses `prefetchOnly` flag to avoid mutating current pagination state.
- **Persistent page count cache**: After `_computeAllPageCounts()` completes, the per-chapter page counts are serialized to a JSON blob (`pageCountsJson` column on `reading_progress` table, migration v11) alongside the raw layout parameters (viewport size + 6 preference values). On subsequent `openBook()`, if the stored parameters match the current viewport and preferences, page counts are restored instantly from DB — skipping the expensive full-book pagination entirely. Uses raw parameter comparison instead of `Object.hash` because hash seeds are randomized per Dart VM invocation.
- **`pageCountOnly` fast pagination mode**: When computing page counts for progress display, `paginate(pageCountOnly: true)` skips the K-P justified layout path (all paragraphs use a single greedy `TextPainter.layout()` instead of per-word measurement + solver + per-fragment painters), skips `LayoutElement` allocation (only tracks a page counter), and skips list marker measurement + positioning. Greedy and K-P produce the same line count ±0-1 per paragraph, so page count accuracy is preserved. Reduces page-count computation time by ~60-75%.
- **K-P solver data structure optimizations**: The active node collection uses `List<_Node>` instead of `Set<_Node>` (avoids iterator/hashCode overhead for the typical 5-15 node set). The `feasible` intermediate list is eliminated — the best feasible node is tracked inline during the active-node loop. The `toRemove` list is eliminated — nodes are removed in-place via `removeAt` during reverse iteration. `hasNegativeValues` is computed once with an early-exit loop instead of `items.any()` with closures.
- **Data source warm-up**: `CachedChapterDataSource.warmUp()` pre-reads `book.json` and the first chapter JSON into memory. Called fire-and-forget in `ReaderEntryService` before `Navigator.push()`, so file I/O overlaps with the route transition animation (~300ms). When `ReaderStore.openBook()` calls `loadBook()`/`loadChapter()`, data is already in memory.
- **Paginate yield**: `_loadChapter()` yields one frame (`await Future.delayed(Duration.zero)`) before calling `paginate()`, preventing the synchronous layout computation from freezing the loading spinner animation.

### Cache Invalidation

Cache key = `(chapterIndex, viewportSize, preferencesLayoutHash)`

Invalidated by: font size/family change, line height change, page margin change, screen rotation

## Key State & Data

- `ReaderStore` (ChangeNotifier): manages book, chapters, pagination cache, current position, preferences
- `ReaderPreferences`: baseFontSizePx, fontFamily, pageHorizontalPaddingPx, pageVerticalPaddingPx, lineHeightMultiplier, paragraphSpacingMultiplier, theme
- `ReadingProgressEntity(bookId, locatorJson, percent, updatedAt, prefsJson, pageCountsJson)`: locatorJson stores `{"chapterIndex": N, "pageIndex": M}`, prefsJson stores per-book ReaderPreferences as JSON, pageCountsJson stores persisted page count cache with layout parameter validation
- `ChapterPagination`: cached per chapter, invalidated on layout parameter changes

## Interaction & Error Handling

- Content area avoids system status bar and bottom gesture area (safe area insets)
- Horizontal swipe page turning: drag left/right to preview next/previous page with follow-the-finger animation; on release, completes page turn (>25% screen width or velocity >500px/s) or snaps back. Rubber-band effect at first/last page of book. Adjacent chapters prefetched for smooth cross-chapter swipe.
- Tap left 30% = previous page, right 30% = next page, center 40% = toggle controls (tap and swipe coexist)
- Text selection via long-press: long-press to select a word, drag to extend. After release, two draggable handles appear for fine adjustment. Tap anywhere to clear selection. Selection is cleared on non-selection page navigation.
- Cross-page selection: dragging a handle to the screen edge (40px zone) for 300ms triggers an animated page turn. The selection extends onto the new page with the anchor end preserved. A thin edge indicator shows when selection continues beyond the visible page. Supports multi-page and cross-chapter selection. Text extraction concatenates across all pages in the selection range.
- AI Explain: selecting text shows a tooltip with "Explain" button. Tapping it opens a bottom sheet that calls an OpenAI-compatible LLM to explain the passage. For single words/phrases: shows the word in large bold text with the containing sentence (word highlighted in bold). For longer selections: shows an italic text preview. Below is the AI explanation rendered as Markdown (no chat input). Prompt detail levels: Brief (1-2 sentences), Balanced (short paragraph, default), Detailed (thorough but focused). Uses `ExplainAiService` backed by Genkit + OpenAI plugin. API credentials configured in Settings page via `AiSettingsService` (SharedPreferences).
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
- `flutter analyze` passes with no issues in reader code

## Non-Goals

- Highlighting in Canvas reader (future work)
- Audio/translation
- TXT/PDF format support
- Real reading time tracking
- flutter_rust_bridge FFI (Phase 2, currently using JSON CLI bridge)
- Full image rendering from EPUB (placeholder only)
