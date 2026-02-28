import 'package:flutter/material.dart';

import '../../entities/book-entity.dart';
import '../../shared/constants/library-design-tokens.dart';
import '../../components/library/library-book-grid.dart';
import '../../components/library/library-category-tabs.dart';
import '../../components/library/library-top-bar.dart';

class LibraryPageLayout extends StatelessWidget {
  const LibraryPageLayout({
    required this.books,
    required this.categories,
    required this.activeCategory,
    required this.isImporting,
    required this.onCategoryTap,
    required this.onBookTap,
    required this.onImportTap,
    required this.onSearchTap,
    required this.onMenuTap,
    super.key,
  });

  final List<BookEntity> books;
  final List<String> categories;
  final String activeCategory;
  final bool isImporting;
  final ValueChanged<String> onCategoryTap;
  final ValueChanged<BookEntity> onBookTap;
  final VoidCallback onImportTap;
  final VoidCallback onSearchTap;
  final VoidCallback onMenuTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: LibraryDesignTokens.pageBackground,
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(
            left: LibraryDesignTokens.pageHorizontal,
            right: LibraryDesignTokens.pageHorizontal,
            top: LibraryDesignTokens.pageTopPadding,
            bottom: 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              LibraryTopBar(
                onSearchTap: onSearchTap,
                onMenuTap: onMenuTap,
                onImportTap: onImportTap,
                isImporting: isImporting,
              ),
              const SizedBox(height: LibraryDesignTokens.topBarBottomGap),
              RichText(
                text: const TextSpan(
                  children: <InlineSpan>[
                    TextSpan(
                      text: 'Library ',
                      style: TextStyle(
                        fontSize: LibraryDesignTokens.libraryTitleSize,
                        fontWeight: FontWeight.w400,
                        color: LibraryDesignTokens.textPrimary,
                        height: 0.96,
                        letterSpacing: -0.8,
                      ),
                    ),
                    TextSpan(
                      text: 'Recent',
                      style: TextStyle(
                        fontSize: LibraryDesignTokens.libraryTitleSize,
                        fontWeight: FontWeight.w700,
                        color: LibraryDesignTokens.textPrimary,
                        height: 0.96,
                        letterSpacing: -0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: LibraryDesignTokens.sectionTitleBottomGap),
              LibraryCategoryTabs(
                items: categories,
                active: activeCategory,
                onChange: onCategoryTap,
              ),
              const SizedBox(height: LibraryDesignTokens.categorySectionBottomGap),
              const Divider(
                color: LibraryDesignTokens.borderColor,
                thickness: LibraryDesignTokens.sectionDividerThickness,
                height: 1,
              ),
              const SizedBox(height: LibraryDesignTokens.sectionDividerBottomGap),
              LibraryBookGrid(
                books: books,
                onBookTap: onBookTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
