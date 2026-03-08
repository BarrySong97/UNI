// Copyright (c) 2021 Mantano. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE.Iridium file.

import 'package:path/path.dart' as p;
import 'package:dartx/dartx.dart';

/// Extension to extract file extension from a path string.
extension StringPathExtension on String {
  /// Returns the file extension without the leading dot.
  String extension() => p.extension(this).removePrefix('.');
}
