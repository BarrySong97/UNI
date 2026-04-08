class ReaderQuoteCardPayload {
  const ReaderQuoteCardPayload({
    required this.bookId,
    required this.bookTitle,
    required this.bookAuthor,
    required this.selectedText,
    this.readerFontFamily,
    this.readerThemeName,
  });

  final String bookId;
  final String bookTitle;
  final String bookAuthor;
  final String selectedText;
  final String? readerFontFamily;
  final String? readerThemeName;
}
