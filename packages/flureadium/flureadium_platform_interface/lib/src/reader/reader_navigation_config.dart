// ignore_for_file: public_member_api_docs, sort_constructors_first

class ReaderNavigationConfig {
  ReaderNavigationConfig({
    this.enableEdgeTapNavigation,
    this.enableSwipeNavigation,
    this.edgeTapAreaPoints,
    this.disableDoubleTapZoom,
    this.disableTextSelection,
    this.disableDragGestures,
    this.disableDoubleTapTextSelection,
  });

  bool? enableEdgeTapNavigation;
  bool? enableSwipeNavigation;
  double? edgeTapAreaPoints;
  bool? disableDoubleTapZoom;
  bool? disableTextSelection;
  bool? disableDragGestures;
  bool? disableDoubleTapTextSelection;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (enableEdgeTapNavigation != null) {
      map['enableEdgeTapNavigation'] = enableEdgeTapNavigation;
    }
    if (enableSwipeNavigation != null) {
      map['enableSwipeNavigation'] = enableSwipeNavigation;
    }
    if (edgeTapAreaPoints != null) map['edgeTapAreaPoints'] = edgeTapAreaPoints;
    if (disableDoubleTapZoom != null) {
      map['disableDoubleTapZoom'] = disableDoubleTapZoom;
    }
    if (disableTextSelection != null) {
      map['disableTextSelection'] = disableTextSelection;
    }
    if (disableDragGestures != null) {
      map['disableDragGestures'] = disableDragGestures;
    }
    if (disableDoubleTapTextSelection != null) {
      map['disableDoubleTapTextSelection'] = disableDoubleTapTextSelection;
    }
    return map;
  }
}
