// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

/// The Flutter painting library.
///
/// To use, import `package:hermit/painting.dart`.
///
/// This library includes a variety of classes that wrap the Flutter
/// engine's painting API for more specialized purposes, such as painting scaled
/// images, interpolating between shadows, painting borders around boxes, etc.
///
/// In particular:
///
///  * Use the [TextPainter] class for painting text.
///  * Use [Decoration] (and more concretely [BoxDecoration]) for
///    painting boxes.
library painting;

export 'src/painting/alignment.dart';
export 'src/painting/basic_types.dart';
export 'src/painting/border_radius.dart';
export 'src/painting/box_fit.dart';
export 'src/painting/colors.dart';
export 'src/painting/debug.dart';
export 'src/painting/edge_insets.dart';
export 'src/painting/fractional_offset.dart';
export 'src/painting/geometry.dart';
export 'src/painting/matrix_utils.dart';