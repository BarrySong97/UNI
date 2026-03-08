import 'package:flureadium_platform_interface/flureadium_platform_interface.dart';

/// Transforms publication JSON from web format to expected format.
class PublicationJsonTransformer {
  /// Transforms publication JSON structure from web implementation to match expected format.
  ///
  /// Handles:
  /// - Unwrapping 'items' wrappers from arrays
  /// - Renaming 'tableOfContents' to 'toc'
  /// - Transforming nested 'children' structures
  /// - Converting 'translations' maps to expected format
  /// - Renaming 'authors' to 'author'
  /// - Handling 'sortAs' field transformations
  static Map<String, dynamic> transform(
    final Map<String, dynamic> publicationJson,
  ) {
    // Transform 'links', 'readingOrder', 'resources', and 'tableOfContents' keys
    _transformKeyItems(publicationJson, 'links');
    _transformKeyItems(publicationJson, 'readingOrder');
    _transformKeyItems(publicationJson, 'resources');

    // rename key 'tableOfContents' to 'toc'
    if (publicationJson.containsKey('tableOfContents')) {
      publicationJson['toc'] = publicationJson.remove('tableOfContents');
    }

    // Transform 'children' key in 'toc'
    if (publicationJson.containsKey('toc') &&
        publicationJson['toc'] is Map<String, dynamic>) {
      _transformKeyItems(publicationJson, 'toc');
      publicationJson['toc'] = _transformChildren(publicationJson['toc']);
    }

    // Transform 'translations' key in 'metadata'
    if (publicationJson.containsKey('metadata') &&
        publicationJson['metadata'] is Map) {
      final metadataMap = publicationJson['metadata'] as Map<String, dynamic>;

      if (metadataMap.containsKey('authors') && metadataMap['authors'] is Map) {
        // rename key 'authors' to 'author'
        metadataMap['author'] = metadataMap.remove('authors');
        // remove 'items' wrapper if exists
        _transformKeyItems(metadataMap, 'author');

        for (final author in metadataMap['author']) {
          if (author is Map &&
              author.containsKey('name') &&
              author['name'] is Map) {
            final nameMap = author['name'] as Map<String, dynamic>;
            if (nameMap.containsKey('translations') &&
                nameMap['translations'] is Map) {
              final translationsMap =
                  nameMap['translations'] as Map<String, dynamic>;
              _validateTranslations(translationsMap);
              author['name'] = translationsMap;
            }
          }
        }
      }

      if (metadataMap.containsKey('title') && metadataMap['title'] is Map) {
        final titleMap = metadataMap['title'] as Map<String, dynamic>;
        if (titleMap.containsKey('translations') &&
            titleMap['translations'] is Map) {
          final translationsMap =
              titleMap['translations'] as Map<String, dynamic>;

          _validateTranslations(translationsMap);

          metadataMap['title'] = translationsMap;
        }
      }

      if (metadataMap.containsKey('sortAs')) {
        final sortAs = metadataMap['sortAs'];
        if (sortAs is Map && sortAs['translations'] is Map) {
          final translations = sortAs['translations'] as Map;
          if (translations.isNotEmpty) {
            // Use the first value in the translations map
            metadataMap['sortAs'] = translations.values.first;
          } else {
            metadataMap['sortAs'] = null;
          }
        } else if (sortAs is! String) {
          metadataMap['sortAs'] = null;
        }
      }
    }

    return publicationJson;
  }

  /// Unwraps 'items' wrapper from arrays if present.
  static void _transformKeyItems(
    final Map<String, dynamic> json,
    final String key,
  ) {
    if (json.containsKey(key) && json[key] is Map) {
      final map = json[key] as Map<String, dynamic>;
      if (map.containsKey('items') && map['items'] is List) {
        json[key] = map['items'];
      }
    }
  }

  /// Recursively transforms 'children' arrays, unwrapping 'items' wrappers.
  static List<dynamic> _transformChildren(final List<dynamic> items) =>
      items.map((final item) {
        if (item is Map<String, dynamic> && item.containsKey('children')) {
          final children = item['children'];
          if (children is Map<String, dynamic> &&
              children.containsKey('items')) {
            item['children'] = children['items'];
          }
          if (item['children'] is List) {
            item['children'] = _transformChildren(item['children']);
          }
        }
        return item;
      }).toList();

  /// Validates and normalizes translation keys.
  ///
  /// Converts 'undefined' to 'und' (ISO 639-3 code for undetermined language).
  /// Logs warning for keys longer than 3 characters.
  static void _validateTranslations(Map<String, dynamic> translationsMap) {
    if (translationsMap.containsKey('undefined')) {
      translationsMap['und'] = translationsMap.remove('undefined');
    }

    // TODO: unknown if other languages also fails the validation, needs better handling
    translationsMap.forEach((final key, final value) {
      if (key.length > 3) {
        R2Log.d(
          'PUBLICATION WEB: Translations map key "$key" is longer than three letters.',
        );
      }
    });
  }
}
