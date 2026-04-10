# Module: library

## Module Purpose
The app has two main book-related pages:
- **Shelf** (`ShelfPage`, tab 0): The home dashboard with reading stats, Now Reading card, a `Words` section fed by Explain history, and a book grid (no category filters).
- **Library** (`LibraryPage`, tab 1): A dedicated book browsing page with category tabs (All/Reading/Finished) and a 2-column book grid.
- **Statistics** (`StatisticsPage`, pushed from Shelf stat cards): A detailed analytics page with separate `Reading Time` and `Books Read` views plus reusable time-block filtering.

Both pages share the same data source (`LibraryStore`) and reusable components (`LibraryBookGrid`, `LibraryHeader`, etc.).

## Boundary
### In
- Shelf dashboard layout (Header / Stats / Now Reading / Words / Book Grid)
- Library page with category filter tabs and 2-column grid
- Statistics page layout and filtering (`This Month` / `This Year` / `Pick Month`)
- Book list loading and display
- "Now Reading" card (based on most recent reading progress; falls back to first book when no progress exists)
- Book grid with cover tiles, title, author, and progress percentage badge
- Book tap routing to Book Profile or reader based on progress
- Unified reader entry policy: overlay-first (from 3-book hot pool) with route fallback
- Import flow entry (Header "+" button on Shelf and Library)
- Import feedback: new book pops in (scale + fade), existing grid items slide to new positions (AnimatedPositioned)
- Empty state handling (no books: "Add Your First Book" button)
- Cover rendering (real cover preferred, fallback placeholder)
- `Book Profile` background gradient and delete functionality
- Category-based filtering (All / Reading / Finished) on Library page

### Out
- Reader text rendering and pagination
- Highlight creation and deletion
- Book format parsing details
- User profile and avatar management

## File Structure
```
lib/pages/shelf/
  shelf-page.dart         — ShelfPage (tab 0, home dashboard)
  shelf-page-layout.dart  — ShelfPageLayout (stateless layout)
  index.dart

lib/pages/library/
  library-page.dart       — LibraryPage (tab 1, category grid)
  book-detail-page.dart   — BookDetailPage (book profile)
  index.dart

lib/pages/statistics/
  statistics-page.dart    — StatisticsPage (reading analytics detail)

lib/components/library/   — Shared components (grid, header, tiles, etc.)
lib/stores/library/       — LibraryStore + LibraryState
```

## Core Flow
1. Page init triggers `LibraryStore.loadShelf()`.
2. Store loads books from DB with reading progress (percent + updatedAt).
3. **ShelfPage** computes derived data:
   - `nowReadingBook`: book with most recent `updatedAt` in `progressUpdatedMap`; first book if no progress.
   - `gridBooks`: remaining books excluding nowReadingBook, sorted by updatedAt descending.
4. **LibraryPage** displays `state.filteredBooks` based on active category:
   - All: all books
   - Reading: progress > 0 and < 1.0
   - Finished: progress >= 1.0
5. User taps any reader entry (Now Reading Continue / Library grid with progress / Book Detail Continue) → uses unified reader entry:
   - If target book is in reader hot pool (up to 3 books): show overlay-first path.
   - Otherwise: fallback to `/reader` route.
6. User taps a book in the grid:
   - No saved progress record: Book Profile (`/book-detail`)
   - Has saved progress record (even if percent is 0): unified reader entry (overlay-first + route fallback)
7. When leaving reader, progress is flushed and `LibraryStore.refreshProgress()` reloads `progressMap/progressUpdatedMap` so grid badges and category filtering update without full page reload.
8. iOS reflowable EPUB visual pagination cache (`reader_visual_pagination_cache`) is shared with Reader as the single source for layout-specific total-page data; Shelf/Library currently still render percent-first UI and do not show live `current/total`.
9. User taps the left Shelf stat card (`Reading Time`) or right Shelf stat card (`Books Read`) -> both navigate to `/statistics`, but pass different initial tab arguments while keeping the same route.
10. Shelf loads recent `Explain` history from `explain_cache` and picks the newest word-like entry (`<= 3` tokens, short text) for the `Words` preview card; the card body prefers the containing sentence, falls back to the selected text, truncates to two lines, and highlights the selected word when it appears in the sentence.
11. User taps `More` in the Shelf `Words` section -> opens the `Words` page, which lists all explain history entries with preview meaning, source book, and time. Tapping a row opens a detail page with full meaning, details, and context sentence.
12. Statistics resolves a reusable time block from the selected preset:
   - `This Month`: current calendar month
   - `This Year`: current calendar year
   - `Pick Month`: selected month start/end
13. Statistics loads both payloads for the selected time block:
   - `Reading Time`: total time, avg/day, chart series, heatmap cells
   - `Books Read`: qualified books + almost-there books

## Page Layout

### Shelf (tab 0)
```
LibraryHeader ("IMMERSED" label + "Shelf" title + "+" import button)
LibraryReadingStats (DAILY GOAL + BOOKS READ) — empty state when no progress
Now Reading (Section Header + NowReadingCard) — first book when no progress
Words (Section Header + preview card + `More`) — shows the latest word in its sentence context or an action hint
Words page — compact history list with row tap to a dedicated detail page
Horizontal book scroll (fixed-width items, edge-to-edge)
```

### Statistics (pushed page)
```
Top bar (back + centered "Statistics")
Time preset control (This Month / This Year / Pick Month)
Tab switch (Reading Time / Books Read) with shared sliding thumb animation

Reading Time:
- Total Time card
- Avg / Day card
- `This Month` / `Pick Month`: 24-hour day-track progress chart
- `This Year`: monthly comparative bar chart
- Reading heatmap

Books Read:
- Goal achievement hero card
- Qualified Books list
- Almost There list
```

### Library (tab 1)
```
LibraryHeader ("IMMERSED" label + "Library" title + "+" import button)
LibraryBookGrid (category tabs: All/Reading/Finished + 2-column grid)
```

### Empty state (no books)
Header + "Add Your First Book" button (on Shelf).

## Key State & Data
- `LibraryState.books`
- `LibraryState.filteredBooks` (filtered by active category)
- `LibraryState.categories` (`['All', 'Reading', 'Finished']`)
- `LibraryState.activeCategory`
- `LibraryState.progressMap` (Map<String, double>)
- `LibraryState.progressUpdatedMap` (Map<String, DateTime>)
- `LibraryState.readingTime` (`ReadingTimeEntity`) — current local calendar month's total reading seconds plus per-day buckets for Shelf's Statistic Card
- `LibraryState.booksReadThisYear` (`int`) — Book Read card count for the current year
- `LibraryState.isLoading / isImporting`
- `StatisticsStore` — page-owned state for selected tab, selected period preset, resolved time block, loading/error state, and loaded statistics payloads
- `book_stats.reading_time_seconds` — per-book cumulative reading time, updated by Reader
- `reading_time_daily(book_id, date_key, duration_seconds)` — per-book per-day reading time aggregation used for Shelf monthly totals and bars
- Book Read aggregation rule is time-block based (`[startInclusive, endExclusive)`), so Shelf can pass a "current year" block now and future pages can reuse the same query with month/custom ranges.
- `BookEntity.coverUrl` (data url cover)
- `BookEntity.profileBgColor` (`#AARRGGBB`)
- `BookEntity.epubFilePath` (relative path, e.g. `books/book_xxx.epub`, resolved at runtime)
- `BookProfileEntryService.resolveEntry(bookId)`

## Interaction & Exceptions
- Loading: shows spinner.
- Empty: no books shows "Add Your First Book" button, hides stats and features.
- Import success: new book pops in (scale + fade), existing items smoothly slide to new positions (no snackbar).
- Cover decode failure: falls back to placeholder cover.
- Now Reading: uses first book when no progress, always shown on Shelf.
- Words section: always shown when Shelf has books; empty state says `Select a word in Reader and tap Explain.` Preview cards show the containing sentence (or the selected sentence itself) and do not show the explain meaning.
- Words `More` page: if no explain history exists, shows the same empty-state guidance instead of a blank list.
- Real cover uses `BoxFit.cover`.
- Book Profile top background uses `profileBgColor` gradient.
- Book Profile settings menu can delete book with cascading cleanup.
- Importing: top linear progress indicator (no blocking overlay).
- Grid items show progress percentage badge (bottom-left, semi-transparent gray `#99666666`, 10px white text, 4px radius) on cover when progress > 0.
- Shelf Statistic Card reads real monthly `ReadingTime` from `reading_time_daily` and shows the current calendar month's cumulative `xh ym` plus normalized daily bars.
- Shelf `BOOKS READ` uses the same time-block aggregation API with the current year block (`YYYY-01-01` to `(YYYY+1)-01-01`) and counts unique books that satisfy both: persisted progress `>= 40%` and aggregated reading time in block `>= 20 minutes` (1200s).
- Statistics page always reuses the same time-block data APIs; changing tabs does not change the current time block.
- Statistics `Reading Time` month views (`This Month` / `Pick Month`) render absolute 24-hour tracks per day: the pale background is a full day and the fill is `seconds / 86400`, with a tiny minimum visible fill for non-zero reading days.
- `Books Read` view shows:
  - qualified books meeting both thresholds
  - almost-there books that meet exactly one threshold and have reading activity in the selected block
- Shelf/Library progress UI keeps using persisted percent as the primary display; if future page-total UI is needed, it must read the shared visual pagination cache instead of `estimated_total_pages`.

## Acceptance Criteria
- Shelf renders stable dashboard (Header / Stats / Now Reading / Words / Grid).
- Library renders category tabs and filtered 2-column grid.
- Now Reading shows most recently read book; first book when no progress.
- Grid tiles show cover, title, author, and progress badge.
- Empty state shows "Add Your First Book" button.
- "Continue" and all progress-based reader entries follow unified overlay-first + route-fallback behavior.
- Statistics route opens from both Shelf stat cards and preserves the selected entry tab.
- Statistics supports `This Month`, `This Year`, and `Pick Month`.
- Imported EPUB shows real cover; other formats show placeholder.
- App restart on iOS doesn't break book file access (relative paths).
- Book deletion cascades to associated data.
- `flutter analyze` / `flutter test` passes.

## Non-Goals
- No recommendation algorithm or bookstore sorting.
- No account or cloud sync.
- Shelf does not implement a rotating dictionary-style word of the day.
