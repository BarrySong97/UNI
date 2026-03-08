// Copyright (c) 2021 Mantano. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE.Iridium file.

import 'dart:convert';

import 'package:dartx/dartx.dart';
import 'package:dfunc/dfunc.dart';
import 'package:equatable/equatable.dart';
import 'package:fimber/fimber.dart';
import 'package:json_annotation/json_annotation.dart';

import '../../utils/additional_properties.dart';
import '../../utils/jsonable.dart';
import '../../extensions/readium_string_extensions.dart';
import '../mediatype/mediatype.dart';
import 'link.dart';
import 'locations.dart';
import 'locator_text.dart';

export 'locations.dart';
export 'locator_text.dart';

// Re-export sentinel values used by Locator.copyWithLocations
const int _emptyIntValue = -1;
const double _emptyDoubleValue = -1;

/// Provides a precise location in a publication in a format that can be stored and shared.
///
/// There are many different use cases for locators:
///  - getting back to the last position in a publication
///  - bookmarks
///  - highlights & annotations
///  - search results
///  - human-readable (and shareable) reference in a publication
///
/// https://github.com/readium/architecture/tree/master/models/locators
class Locator extends AdditionalProperties
    with EquatableMixin
    implements JSONable {
  const Locator({
    required this.href,
    required this.type,
    this.text,
    this.locations,
    this.title,
    super.additionalProperties,
  }) : super();

  final String href;
  final String type;
  final String? title;
  final Locations? locations;
  final LocatorText? text;

  static Locator? fromJsonString(String jsonString) {
    try {
      //Fimber.d("jsonString $jsonString");
      final Map<String, dynamic> json = JsonCodec().decode(jsonString);
      return Locator.fromJson(json);
    } on Object catch (ex, st) {
      Fimber.e('ERROR', ex: ex, stacktrace: st);
    }
    return null;
  }

  static Locator? fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }

    final href = json.safeRemove<String>('href');
    final type = json.safeRemove<String>('type');
    if (href == null || type == null) {
      Fimber.i('[href] and [type] are required $json');
      return null;
    }

    final title = json.safeRemove<String>('title');
    final locations = Locations.fromJson(json.optJsonObject('locations'));
    final text = LocatorText.fromJson(json.optJsonObject('text'));

    return Locator(
      href: href,
      type: type,
      title: title,
      locations: locations,
      text: text,
      additionalProperties: json,
    );
  }

  String get json => JsonCodec().encode(toJson());

  @override
  Map<String, dynamic> toJson() => {'href': href, 'type': type}
    ..putOpt('title', title)
    ..putJSONableIfNotEmpty('locations', locations)
    ..putJSONableIfNotEmpty('text', text);

  Locator copyWith({
    String? href,
    String? type,
    String? title,
    Locations? locations,
    LocatorText? text,
    Map<String, dynamic>? additionalProperties,
  }) {
    final mergeProperties = Map<String, dynamic>.of(this.additionalProperties)
      ..addAll(additionalProperties ?? {})
      ..removeWhere((key, value) => value == null);

    return Locator(
      href: href ?? this.href,
      type: type ?? this.type,
      title: title ?? this.title,
      locations: locations ?? this.locations,
      text: text ?? this.text,
      additionalProperties: mergeProperties,
    );
  }

  /// Shortcut to get a copy of the [Locator] with different [Locations] sub-properties.
  Locator copyWithLocations({
    List<String>? fragments,
    double? progression = _emptyDoubleValue,
    int? position = _emptyIntValue,
    double? totalProgression = _emptyDoubleValue,
    Map<String, dynamic>? otherLocations,
  }) => copyWith(
    locations: (locations ?? Locations()).copyWith(
      fragments: fragments ?? locations?.fragments,
      progression: progression.check(locations?.progression),
      position: position.check(locations?.position),
      totalProgression: totalProgression.check(locations?.totalProgression),
      additionalProperties: otherLocations ?? locations?.additionalProperties,
    ),
  );

  /// Returns /path from [href] without #fragment and query parameters.
  String get hrefPath {
    final path = href.path;

    if (path == null) {
      return href;
    }

    return path;
  }

  @override
  List<Object?> get props => [href, type, title, locations, text];

  @override
  String toString() =>
      'Locator{href: $href, type: $type, title: $title, '
      'locations: $locations, text: $text}';

  Locator toTextLocator() {
    // WORKAROUND:
    // Sometimes readium handled any fragments as an `id` fragment and tries to scroll
    // to it as fx. [readium.scrollToId('t=287.55899999999997')] which will cause the book
    // starts from the beginning.
    // Only set id fragments to less confusing readium.
    final selector =
        locations?.cssSelector ?? locations?.domRange?.start.cssSelector;
    final idFragment = selector?.startsWith('#') == true
        ? selector!.substring(1)
        : null;
    // Make sure href only contains path.
    final locationHref = hrefPath.startsWith('/')
        ? hrefPath.substring(1)
        : hrefPath;

    return copyWith(
      // Makes sure href only contains /path.
      href: locationHref,
      type: MediaType.html.name,
      locations: locations?.copyWith(
        fragments: idFragment == null ? null : [idFragment],
      ),
    );
  }
}

extension LinkLocator on Link {
  /// Creates a [Locator] from a reading order [Link].
  Locator toLocator() {
    final components = href.split('#');
    final fragment = (components.length > 1) ? components[1] : null;
    return Locator(
      href: components.firstOrDefault(href),
      type: type ?? '',
      title: title,
      text: LocatorText(),
      locations: Locations(fragments: fragment?.let((it) => [it]) ?? []),
    );
  }
}

class LocatorJsonConverter
    extends JsonConverter<Locator, Map<String, dynamic>?> {
  const LocatorJsonConverter();

  @override
  Locator fromJson(Map<String, dynamic>? json) => Locator.fromJson(json)!;

  @override
  Map<String, dynamic>? toJson(Locator? locator) => locator?.toJson();
}
