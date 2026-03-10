# Module: library

## Module Purpose
The app has two main book-related pages:
- **Shelf** (`ShelfPage`, tab 0): The home dashboard with reading stats, Now Reading card, Word of Day, and a book grid (no category filters).
- **Library** (`LibraryPage`, tab 1): A dedicated book browsing page with category tabs (All/Reading/Finished) and a 2-column book grid.

Both pages share the same data source (`LibraryStore`) and reusable components (`LibraryBookGrid`, `LibraryHeader`, etc.).

## Boundary
### In
- Shelf dashboard layout (Header / Stats / Now Reading / Word of the Day / Book Grid)
- Library page with category filter tabs and 2-column grid
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

## Page Layout

### Shelf (tab 0)
```
LibraryHeader ("IMMERSED" label + "Shelf" title + "+" import button)
LibraryReadingStats (DAILY GOAL + BOOKS READ) — empty state when no progress
Now Reading (Section Header + NowReadingCard) — first book when no progress
WordOfDayCard — replaced by reading prompt when no progress
Horizontal book scroll (fixed-width items, edge-to-edge)
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
- `LibraryState.isLoading / isImporting`
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
- Real cover uses `BoxFit.cover`.
- Book Profile top background uses `profileBgColor` gradient.
- Book Profile settings menu can delete book with cascading cleanup.
- Importing: top linear progress indicator (no blocking overlay).
- Grid items show progress percentage badge (top-right) on cover.

## Acceptance Criteria
- Shelf renders stable dashboard (Header / Stats / Now Reading / Word of Day / Grid).
- Library renders category tabs and filtered 2-column grid.
- Now Reading shows most recently read book; first book when no progress.
- Grid tiles show cover, title, author, and progress badge.
- Empty state shows "Add Your First Book" button.
- "Continue" and all progress-based reader entries follow unified overlay-first + route-fallback behavior.
- Imported EPUB shows real cover; other formats show placeholder.
- App restart on iOS doesn't break book file access (relative paths).
- Book deletion cascades to associated data.
- `flutter analyze` / `flutter test` passes.

## Non-Goals
- No recommendation algorithm or bookstore sorting.
- No account or cloud sync.
- Word of the Day is static placeholder.
- Reading duration stats are mock data.
