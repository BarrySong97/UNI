// ignore_for_file: public_member_api_docs, sort_constructors_first

/// PDF reader preferences for Flureadium.
///
/// Based on Readium PDF navigator preferences:
/// - fit: How the page fits in the viewport (width, contain)
/// - scrollMode: Scroll orientation (horizontal, vertical)
/// - pageLayout: Single page or double spread
/// - offsetFirstPage: Offset for first page in spreads (for covers)
class PDFPreferences {
  PDFPreferences({
    this.fit,
    this.scrollMode,
    this.pageLayout,
    this.offsetFirstPage,
  });

  factory PDFPreferences.fromJsonMap(Map<String, dynamic> map) =>
      PDFPreferences(
        fit: map['fit'] != null
            ? PDFFit.values.byName(map['fit'] as String)
            : null,
        scrollMode: map['scrollMode'] != null
            ? PDFScrollMode.values.byName(map['scrollMode'] as String)
            : null,
        pageLayout: map['pageLayout'] != null
            ? PDFPageLayout.values.byName(map['pageLayout'] as String)
            : null,
        offsetFirstPage: map['offsetFirstPage'] as bool?,
      );

  /// How the page fits in the viewport.
  PDFFit? fit;

  /// Scroll orientation.
  PDFScrollMode? scrollMode;

  /// Page layout mode.
  PDFPageLayout? pageLayout;

  /// Whether to offset the first page in double-page spreads (for covers).
  bool? offsetFirstPage;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (fit != null) map['fit'] = fit!.name;
    if (scrollMode != null) map['scrollMode'] = scrollMode!.name;
    if (pageLayout != null) map['pageLayout'] = pageLayout!.name;
    if (offsetFirstPage != null) map['offsetFirstPage'] = offsetFirstPage;
    return map;
  }

  PDFPreferences copyWith({
    PDFFit? fit,
    PDFScrollMode? scrollMode,
    PDFPageLayout? pageLayout,
    bool? offsetFirstPage,
  }) => PDFPreferences(
    fit: fit ?? this.fit,
    scrollMode: scrollMode ?? this.scrollMode,
    pageLayout: pageLayout ?? this.pageLayout,
    offsetFirstPage: offsetFirstPage ?? this.offsetFirstPage,
  );
}

/// How a PDF page fits within the viewport.
enum PDFFit {
  /// Fit page width to viewport width.
  width,

  /// Fit entire page in viewport.
  contain,
}

/// Scroll direction for PDF navigation.
enum PDFScrollMode {
  /// Scroll horizontally between pages.
  horizontal,

  /// Scroll vertically through pages.
  vertical,
}

/// Page layout mode for PDF display.
enum PDFPageLayout {
  /// Display one page at a time.
  single,

  /// Display two pages side-by-side (spreads).
  double,

  /// Automatically choose based on viewport.
  automatic,
}
