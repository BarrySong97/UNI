class ReaderQuoteCardPayload {
  const ReaderQuoteCardPayload({
    required this.bookId,
    required this.bookTitle,
    required this.bookAuthor,
    required this.selectedText,
    this.readerFontFamily,
    this.readerThemeName,
    this.coverDataUrl,
    this.chapterTitle,
    this.pageLabel,
    this.collectionLabel,
  });

  final String bookId;
  final String bookTitle;
  final String bookAuthor;
  final String selectedText;
  final String? readerFontFamily;
  final String? readerThemeName;
  final String? coverDataUrl;
  final String? chapterTitle;
  final String? pageLabel;
  final String? collectionLabel;
}
