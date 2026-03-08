// Copyright (c) 2021 Mantano. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE.Iridium file.

import 'package:dfunc/dfunc.dart';
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

import '../../utils/additional_properties.dart';
import '../../utils/jsonable.dart';
import '../../utils/take.dart';
import 'html/dom_range.dart';

const int _emptyIntValue = -1;
const double _emptyDoubleValue = -1;

extension IntCheck on int? {
  int? check(int? defaultValue) =>
      (this == _emptyIntValue) ? defaultValue : this;
}

extension DoubleCheck on double? {
  double? check(double? defaultValue) =>
      (this == _emptyDoubleValue) ? defaultValue : this;
}

/// One or more alternative expressions of the location.
/// https://github.com/readium/architecture/tree/master/models/locators#the-location-object
/// https://github.com/readium/architecture/blob/master/models/locators/extensions/html.md
///
/// @param fragments Contains one or more fragment in the resource referenced by the [Locator].
/// @param progression Progression in the resource expressed as a percentage (between 0 and 1).
/// @param position An index in the publication (>= 1).
/// @param totalProgression Progression in the publication expressed as a percentage (between 0
///        and 1).
/// @param otherLocations Additional locations for extensions.
class Locations extends AdditionalProperties
    with EquatableMixin
    implements JSONable {
  const Locations({
    this.position,
    this.progression,
    this.totalProgression,
    this.cssSelector,
    this.fragments = const [],
    this.domRange,
    this.partialCfi,
    super.additionalProperties,
  });

  factory Locations.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return Locations();
    }

    final jsonObject = Map<String, dynamic>.of(json);
    final fragments =
        jsonObject
            .optStringsFromArrayOrSingle('fragments', remove: true)
            .takeIf((it) => it.isNotEmpty) ??
        jsonObject.optStringsFromArrayOrSingle('fragment', remove: true);

    final progression = jsonObject
        .optNullableDouble('progression', remove: true)
        ?.takeIf((it) => 0.0 <= it && it <= 1.0);
    final position = jsonObject
        .optNullableInt('position', remove: true)
        ?.takeIf((it) => it > 0);

    final totalProgression = jsonObject
        .optPositiveDouble('totalProgression', remove: true)
        ?.takeIf((it) => 0.0 <= it && it <= 1.0);

    final cssSelector = jsonObject.optNullableString(
      'cssSelector',
      remove: true,
    );
    final domRange = DomRange.fromJson(
      jsonObject.optJsonObject('domRange', remove: true),
    );
    final partialCfi = jsonObject.optNullableString('partialCfi', remove: true);

    return Locations(
      fragments: fragments,
      progression: progression,
      position: position,
      totalProgression: totalProgression,
      cssSelector: cssSelector,
      domRange: domRange,
      partialCfi: partialCfi,
      additionalProperties: jsonObject,
    );
  }

  final int? position;
  final double? progression;
  final double? totalProgression;
  final List<String> fragments;
  final String? cssSelector;
  final DomRange? domRange;
  final String? partialCfi;

  Locations copyWith({
    int? position = _emptyIntValue,
    double? progression = _emptyDoubleValue,
    double? totalProgression = _emptyDoubleValue,
    List<String>? fragments,
    Map<String, dynamic>? additionalProperties,
    String? cssSelector,
    DomRange? domRange,
    String? partialCfi,
  }) {
    final mergeProperties = Map<String, dynamic>.of(this.additionalProperties)
      ..addAll(additionalProperties ?? {})
      ..removeWhere((key, value) => value == null);

    return Locations(
      progression: progression.check(this.progression),
      position: position.check(this.position),
      totalProgression: totalProgression.check(this.totalProgression),
      fragments: fragments ?? this.fragments,
      cssSelector: cssSelector ?? this.cssSelector,
      domRange: domRange ?? this.domRange,
      partialCfi: partialCfi ?? this.partialCfi,
      additionalProperties: mergeProperties,
    );
  }

  int get timestamp {
    if (fragments.isEmpty) {
      return 0;
    }
    final timeFragment = fragments.firstWhere(
      (e) => e.startsWith('t='),
      orElse: () => 't=0',
    );
    return int.parse(timeFragment.replaceFirst('t=', ''));
  }

  @override
  Map<String, dynamic> toJson() => Map.of(additionalProperties)
    ..putIterableIfNotEmpty('fragments', fragments)
    ..putOpt('progression', progression)
    ..putOpt('position', position)
    ..putOpt('totalProgression', totalProgression)
    ..putOpt('cssSelector', cssSelector)
    ..putOpt('partialCfi', partialCfi)
    ..putJSONableIfNotEmpty('domRange', domRange);

  @override
  List<Object?> get props => [
    position,
    progression,
    totalProgression,
    fragments,
    additionalProperties,
    cssSelector,
  ];

  @override
  String toString() =>
      'Location{position: $position, progression: $progression, '
      'totalProgression: $totalProgression, fragments: $fragments}, '
      'otherLocations: $additionalProperties, cssSelector: $cssSelector}';
}

extension HTMLLocationsExtension on Locations {
  /// [partialCfi] is an expression conforming to the "right-hand" side of the EPUB CFI syntax, that is
  /// to say: without the EPUB-specific OPF spine item reference that precedes the first ! exclamation
  /// mark (which denotes the "step indirection" into a publication document). Note that the wrapping
  /// epubcfi(***) syntax is not used for the [partialCfi] string, i.e. the "fragment" part of the CFI
  /// grammar is ignored.
  String? get partialCfi => this['partialCfi'] as String?;

  /// An HTML DOM range.
  DomRange? get domRange => (this['domRange'] as Map<String, dynamic>?)?.let(
    (it) => DomRange.fromJson(it),
  );
}

class LocationsJsonConverter
    extends JsonConverter<Locations?, Map<String, dynamic>?> {
  const LocationsJsonConverter();

  @override
  Locations? fromJson(Map<String, dynamic>? json) => Locations.fromJson(json);

  @override
  Map<String, dynamic>? toJson(Locations? locations) => locations?.toJson();
}
