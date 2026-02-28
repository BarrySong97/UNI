class RouteGuards {
  const RouteGuards._();

  static bool canOpenReader(String? bookId) {
    return bookId != null && bookId.isNotEmpty;
  }
}
