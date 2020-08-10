// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'dart:io' show Platform;
import 'package:hermit/ui.dart' as ui show Window;

import 'package:hermit/foundation.dart';
import 'package:vector_math/vector_math_64.dart';

import 'binding.dart';
import 'object.dart';

/// The layout constraints for the root render object.
@immutable
class ViewConfiguration {
  /// Creates a view configuration.
  ///
  /// By default, the view has zero [size] and a [devicePixelRatio] of 1.0.
  const ViewConfiguration({
    this.size = Size.zero,
    this.devicePixelRatio = 1.0,
  });

  /// The size of the output surface.
  final Size size;

  /// The pixel density of the output surface.
  final double devicePixelRatio;

  /// Creates a transformation matrix that applies the [devicePixelRatio].
  Matrix4 toMatrix() {
    return Matrix4.diagonal3Values(devicePixelRatio, devicePixelRatio, 1.0);
  }

  @override
  String toString() => '$size at ${debugFormatDouble(devicePixelRatio)}x';
}

/// The root of the render tree.
///
/// The view represents the total output surface of the render tree and handles
/// bootstrapping the rendering pipeline. The view has a unique child
/// [RenderBox], which is required to fill the entire output surface.
class RenderView extends RenderObject with RenderObjectWithChildMixin<RenderObject> {
  /// Creates the root of the render tree.
  ///
  /// Typically created by the binding (e.g., [RendererBinding]).
  ///
  /// The [configuration] must not be null.
  RenderView({
    RenderObject child,
    @required ViewConfiguration configuration,
    @required ui.Window window,
  }) : assert(configuration != null),
       _configuration = configuration,
       _window = window {
    this.child = child;
  }

  /// The constraints used for the root layout.
  ViewConfiguration get configuration => _configuration;
  ViewConfiguration _configuration;
  /// The configuration is initially set by the `configuration` argument
  /// passed to the constructor.
  ///
  /// Always call [prepareInitialFrame] before changing the configuration.
  set configuration(ViewConfiguration value) {
    assert(value != null);
    if (configuration == value)
      return;
    _configuration = value;
    // TODO(pixeltoast): markNeedsLayout();
  }

  final ui.Window _window;

  // We never call layout() on this class, so this should never get
  // checked. (This class is laid out using scheduleInitialLayout().)
  @override
  void debugAssertDoesMeetConstraints() { assert(false); }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    // call to ${super.debugFillProperties(description)} is omitted because the
    // root superclasses don't include any interesting information for this
    // class
    assert(() {
      properties.add(DiagnosticsNode.message('debug mode enabled - ${kIsWeb ? 'Web' :  Platform.operatingSystem}'));
      return true;
    }());
    properties.add(DiagnosticsProperty<Size>('window size', _window.physicalSize, tooltip: 'in physical pixels'));
    properties.add(DoubleProperty('device pixel ratio', _window.devicePixelRatio, tooltip: 'physical pixels per logical pixel'));
    properties.add(DiagnosticsProperty<ViewConfiguration>('configuration', configuration, tooltip: 'in logical pixels'));
  }
}
