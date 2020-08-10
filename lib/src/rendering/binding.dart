// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'dart:async';
import 'dart:developer';

import 'package:hermit/foundation.dart';
import 'package:hermit/scheduler.dart';
import 'package:hermit/services.dart';

import 'object.dart';
import 'view.dart';

// Examples can assume:
// dynamic context;

/// The glue between the render tree and the Flutter engine.
mixin RendererBinding on BindingBase, ServicesBinding, SchedulerBinding {
  @override
  void initInstances() {
    super.initInstances();
    _instance = this;
    _pipelineOwner = PipelineOwner(
      onNeedVisualUpdate: ensureVisualUpdate,
    );
    window
      ..onMetricsChanged = handleMetricsChanged
      ..onTextScaleFactorChanged = handleTextScaleFactorChanged
      ..onPlatformBrightnessChanged = handlePlatformBrightnessChanged;
    initRenderView();
    assert(renderView != null);
  }

  /// The current [RendererBinding], if one has been created.
  static RendererBinding get instance => _instance;
  static RendererBinding _instance;

  /// Creates a [RenderView] object to be the root of the
  /// [RenderObject] rendering tree, and initializes it so that it
  /// will be rendered when the next frame is requested.
  ///
  /// Called automatically when the binding is created.
  void initRenderView() {
    assert(renderView == null);
    renderView = RenderView(configuration: createViewConfiguration(), window: window);
  }

  /// The render tree's owner, which maintains dirty state for layout,
  /// composite, paint, and accessibility semantics
  PipelineOwner get pipelineOwner => _pipelineOwner;
  PipelineOwner _pipelineOwner;

  /// The render tree that's attached to the output surface.
  RenderView get renderView => _pipelineOwner.rootNode as RenderView;
  /// Sets the given [RenderView] object (which must not be null), and its tree, to
  /// be the new render tree to display. The previous tree, if any, is detached.
  set renderView(RenderView value) {
    assert(value != null);
    _pipelineOwner.rootNode = value;
  }

  /// Called when the system metrics change.
  ///
  /// See [Window.onMetricsChanged].
  @protected
  void handleMetricsChanged() {
    assert(renderView != null);
    renderView.configuration = createViewConfiguration();
    scheduleForcedFrame();
  }

  /// Called when the platform text scale factor changes.
  ///
  /// See [Window.onTextScaleFactorChanged].
  @protected
  void handleTextScaleFactorChanged() { }

  /// Called when the platform brightness changes.
  ///
  /// The current platform brightness can be queried from a Flutter binding or
  /// from a [MediaQuery] widget. The latter is preferred from widgets because
  /// it causes the widget to be automatically rebuilt when the brightness
  /// changes.
  ///
  /// {@tool snippet}
  /// Querying [Window.platformBrightness].
  ///
  /// ```dart
  /// final Brightness brightness = WidgetsBinding.instance.window.platformBrightness;
  /// ```
  /// {@end-tool}
  ///
  /// {@tool snippet}
  /// Querying [MediaQuery] directly. Preferred.
  ///
  /// ```dart
  /// final Brightness brightness = MediaQuery.platformBrightnessOf(context);
  /// ```
  /// {@end-tool}
  ///
  /// {@tool snippet}
  /// Querying [MediaQueryData].
  ///
  /// ```dart
  /// final MediaQueryData mediaQueryData = MediaQuery.of(context);
  /// final Brightness brightness = mediaQueryData.platformBrightness;
  /// ```
  /// {@end-tool}
  ///
  /// See [Window.onPlatformBrightnessChanged].
  @protected
  void handlePlatformBrightnessChanged() { }

  /// Returns a [ViewConfiguration] configured for the [RenderView] based on the
  /// current environment.
  ///
  /// This is called during construction and also in response to changes to the
  /// system metrics.
  ///
  /// Bindings can override this method to change what size or device pixel
  /// ratio the [RenderView] will use. For example, the testing framework uses
  /// this to force the display into 800x600 when a test is run on the device
  /// using `flutter run`.
  ViewConfiguration createViewConfiguration() {
    final double devicePixelRatio = window.devicePixelRatio;
    return ViewConfiguration(
      size: window.physicalSize / devicePixelRatio,
      devicePixelRatio: devicePixelRatio,
    );
  }

  int _firstFrameDeferredCount = 0;
  bool _firstFrameSent = false;

  /// Whether frames produced by [drawFrame] are sent to the engine.
  ///
  /// If false the framework will do all the work to produce a frame,
  /// but the frame is never sent to the engine to actually appear on screen.
  ///
  /// See also:
  ///
  ///  * [deferFirstFrame], which defers when the first frame is sent to the
  ///    engine.
  bool get sendFramesToEngine => _firstFrameSent || _firstFrameDeferredCount == 0;

  /// Tell the framework to not send the first frames to the engine until there
  /// is a corresponding call to [allowFirstFrame].
  ///
  /// Call this to perform asynchronous initialization work before the first
  /// frame is rendered (which takes down the splash screen). The framework
  /// will still do all the work to produce frames, but those frames are never
  /// sent to the engine and will not appear on screen.
  ///
  /// Calling this has no effect after the first frame has been sent to the
  /// engine.
  void deferFirstFrame() {
    assert(_firstFrameDeferredCount >= 0);
    _firstFrameDeferredCount += 1;
  }

  /// Called after [deferFirstFrame] to tell the framework that it is ok to
  /// send the first frame to the engine now.
  ///
  /// For best performance, this method should only be called while the
  /// [schedulerPhase] is [SchedulerPhase.idle].
  ///
  /// This method may only be called once for each corresponding call
  /// to [deferFirstFrame].
  void allowFirstFrame() {
    assert(_firstFrameDeferredCount > 0);
    _firstFrameDeferredCount -= 1;
    // Always schedule a warm up frame even if the deferral count is not down to
    // zero yet since the removal of a deferral may uncover new deferrals that
    // are lower in the widget tree.
    if (!_firstFrameSent)
      scheduleWarmUpFrame();
  }

  /// Call this to pretend that no frames have been sent to the engine yet.
  ///
  /// This is useful for tests that want to call [deferFirstFrame] and
  /// [allowFirstFrame] since those methods only have an effect if no frames
  /// have been sent to the engine yet.
  void resetFirstFrameSent() {
    _firstFrameSent = false;
  }

  @override
  Future<void> performReassemble() async {
    await super.performReassemble();
    Timeline.startSync('Dirty Render Tree', arguments: timelineArgumentsIndicatingLandmarkEvent);
    try {
      renderView.reassemble();
    } finally {
      Timeline.finishSync();
    }
    scheduleWarmUpFrame();
    await endOfFrame;
  }
}

/// Prints a textual representation of the entire render tree.
void debugDumpRenderTree() {
  debugPrint(RendererBinding.instance?.renderView?.toStringDeep() ?? 'Render tree unavailable.');
}

/// A concrete binding for applications that use the Rendering framework
/// directly. This is the glue that binds the framework to the Flutter engine.
///
/// You would only use this binding if you are writing to the
/// rendering layer directly. If you are writing to a higher-level
/// library, such as the Flutter Widgets library, then you would use
/// that layer's binding.
class RenderingFlutterBinding extends BindingBase with SchedulerBinding, ServicesBinding, RendererBinding {
  /// Creates a binding for the rendering layer.
  ///
  /// The `root` render box is attached directly to the [renderView] and is
  /// given constraints that require it to fill the window.
  RenderingFlutterBinding({ RenderObject root }) {
    assert(renderView != null);
    renderView.child = root;
  }
}
