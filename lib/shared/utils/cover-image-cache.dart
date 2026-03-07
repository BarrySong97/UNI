import 'dart:convert';
import 'dart:typed_data';

/// In-memory cache for decoded cover image bytes.
///
/// Book covers are stored as base64 data URLs. Decoding them is expensive and
/// the result never changes for a given URL, so we cache the decoded bytes
/// keyed by the data URL's identity hash to avoid re-decoding on every widget
/// rebuild.
abstract final class CoverImageCache {
  static final Map<int, Uint8List?> _cache = <int, Uint8List?>{};

  /// Returns decoded bytes for [dataUrl], using the cache when available.
  static Uint8List? decode(String? dataUrl) {
    if (dataUrl == null || !dataUrl.startsWith('data:image/')) {
      return null;
    }
    final key = identityHashCode(dataUrl);
    if (_cache.containsKey(key)) {
      return _cache[key];
    }
    const marker = ';base64,';
    final markerIndex = dataUrl.indexOf(marker);
    if (markerIndex <= 0 || markerIndex + marker.length >= dataUrl.length) {
      _cache[key] = null;
      return null;
    }
    final payload = dataUrl.substring(markerIndex + marker.length);
    try {
      final bytes = base64Decode(payload);
      _cache[key] = bytes;
      return bytes;
    } catch (_) {
      _cache[key] = null;
      return null;
    }
  }

  /// Removes a single entry (e.g. after a book is deleted).
  static void evict(String? dataUrl) {
    if (dataUrl == null) return;
    _cache.remove(identityHashCode(dataUrl));
  }

  /// Clears the entire cache.
  static void clear() => _cache.clear();
}
