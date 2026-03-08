// Copyright (c) 2021 Mantano. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE.Iridium file.

import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

import '../../utils/jsonable.dart';

/// Textual context of the locator.
///
/// A Locator Text Object contains multiple text fragments, useful to give a context to the
/// [Locator] or for highlights.
/// https://github.com/readium/architecture/tree/master/models/locators#the-text-object
///
/// @param before The text before the locator.
/// @param highlight The text at the locator.
/// @param after The text after the locator.
class LocatorText with EquatableMixin implements JSONable {
  factory LocatorText.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const LocatorText();
    }

    final jsonObject = Map<String, dynamic>.of(json);
    return LocatorText(
      before: jsonObject.optNullableString('before', remove: true),
      highlight: jsonObject.optNullableString('highlight', remove: true),
      after: jsonObject.optNullableString('after', remove: true),
    );
  }

  const LocatorText({this.before, this.highlight, this.after});
  final String? before;
  final String? highlight;
  final String? after;

  @override
  Map<String, dynamic> toJson() => {}
    ..putOpt('before', before)
    ..putOpt('highlight', highlight)
    ..putOpt('after', after);

  @override
  List<Object?> get props => [before, highlight, after];
}

class LocatorTextJsonConverter
    extends JsonConverter<LocatorText?, Map<String, dynamic>?> {
  const LocatorTextJsonConverter();

  @override
  LocatorText? fromJson(Map<String, dynamic>? json) =>
      LocatorText.fromJson(json);

  @override
  Map<String, dynamic>? toJson(LocatorText? locatorText) =>
      locatorText?.toJson();
}
