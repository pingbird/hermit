// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'dart:async';
import 'dart:typed_data';
import 'package:hermit/ui.dart' as ui;

import 'package:hermit/foundation.dart';
import 'package:hermit/scheduler.dart';

import 'asset_bundle.dart';

/// Listens for platform messages and directs them to the [defaultBinaryMessenger].
///
/// The [ServicesBinding] also registers a [LicenseEntryCollector] that exposes
/// the licenses found in the `LICENSE` file stored at the root of the asset
/// bundle, and implements the `ext.flutter.evict` service extension (see
/// [evict]).
mixin ServicesBinding on BindingBase, SchedulerBinding {
  @override
  void initInstances() {
    super.initInstances();
    _instance = this;
    initLicenses();
    readInitialLifecycleStateFromNativeWindow();
  }

  /// The current [ServicesBinding], if one has been created.
  static ServicesBinding get instance => _instance;
  static ServicesBinding _instance;

  /// Called when the operating system notifies the application of a memory
  /// pressure situation.
  ///
  /// This method exposes the `memoryPressure` notification from
  /// [SystemChannels.system].
  @protected
  @mustCallSuper
  void handleMemoryPressure() { }

  /// Handler called for messages received on the [SystemChannels.system]
  /// message channel.
  ///
  /// Other bindings may override this to respond to incoming system messages.
  @protected
  @mustCallSuper
  Future<void> handleSystemMessage(Object systemMessage) async {
    final Map<String, dynamic> message = systemMessage as Map<String, dynamic>;
    final String type = message['type'] as String;
    switch (type) {
      case 'memoryPressure':
        handleMemoryPressure();
        break;
    }
    return;
  }

  /// Adds relevant licenses to the [LicenseRegistry].
  ///
  /// By default, the [ServicesBinding]'s implementation of [initLicenses] adds
  /// all the licenses collected by the `flutter` tool during compilation.
  @protected
  @mustCallSuper
  void initLicenses() {
    LicenseRegistry.addLicense(_addLicenses);
  }

  Stream<LicenseEntry> _addLicenses() async* {
    // Using _something_ here to break
    // this into two parts is important because isolates take a while to copy
    // data at the moment, and if we receive the data in the same event loop
    // iteration as we send the data to the next isolate, we are definitely
    // going to miss frames. Another solution would be to have the work all
    // happen in one isolate, and we may go there eventually, but first we are
    // going to see if isolate communication can be made cheaper.
    // See: https://github.com/dart-lang/sdk/issues/31959
    //      https://github.com/dart-lang/sdk/issues/31960
    // TODO(ianh): Remove this complexity once these bugs are fixed.
    final Completer<String> rawLicenses = Completer<String>();
    scheduleTask(() async {
      // TODO(jonahwilliams): temporary catch to allow migrating LICENSE to NOTICES.
      // Once both the tool and google3 use notices this can be removed after PR:
      // https://github.com/flutter/flutter/pull/57871
      try {
        rawLicenses.complete(await rootBundle.loadString('NOTICES', cache: false));
      } on FlutterError {
        rawLicenses.complete(await rootBundle.loadString('LICENSE', cache: false));
      }
    }, Priority.animation);
    await rawLicenses.future;
    final Completer<List<LicenseEntry>> parsedLicenses = Completer<List<LicenseEntry>>();
    scheduleTask(() async {
      parsedLicenses.complete(_parseLicenses(await rawLicenses.future));
    }, Priority.animation);
    await parsedLicenses.future;
    yield* Stream<LicenseEntry>.fromIterable(await parsedLicenses.future);
  }

  // This is run in another isolate created by _addLicenses above.
  static List<LicenseEntry> _parseLicenses(String rawLicenses) {
    final String _licenseSeparator = '\n' + ('-' * 80) + '\n';
    final List<LicenseEntry> result = <LicenseEntry>[];
    final List<String> licenses = rawLicenses.split(_licenseSeparator);
    for (final String license in licenses) {
      final int split = license.indexOf('\n\n');
      if (split >= 0) {
        result.add(LicenseEntryWithLineBreaks(
          license.substring(0, split).split('\n'),
          license.substring(split + 2),
        ));
      } else {
        result.add(LicenseEntryWithLineBreaks(const <String>[], license));
      }
    }
    return result;
  }

  @override
  void initServiceExtensions() {
    super.initServiceExtensions();

    assert(() {
      registerStringServiceExtension(
        // ext.flutter.evict value=foo.png will cause foo.png to be evicted from
        // the rootBundle cache and cause the entire image cache to be cleared.
        // This is used by hot reload mode to clear out the cache of resources
        // that have changed.
        name: 'evict',
        getter: () async => '',
        setter: (String value) async {
          evict(value);
        },
      );
      return true;
    }());
  }

  /// Called in response to the `ext.flutter.evict` service extension.
  ///
  /// This is used by the `flutter` tool during hot reload so that any images
  /// that have changed on disk get cleared from caches.
  @protected
  @mustCallSuper
  void evict(String asset) {
    rootBundle.evict(asset);
  }

  // App life cycle

  /// Initializes the [lifecycleState] with the [initialLifecycleState] from the
  /// window.
  ///
  /// Once the [lifecycleState] is populated through any means (including this
  /// method), this method will do nothing. This is because the
  /// [initialLifecycleState] may already be stale and it no longer makes sense
  /// to use the initial state at dart vm startup as the current state anymore.
  ///
  /// The latest state should be obtained by subscribing to
  /// [WidgetsBindingObserver.didChangeAppLifecycleState].
  @protected
  void readInitialLifecycleStateFromNativeWindow() {
    if (lifecycleState != null) {
      return;
    }
    final AppLifecycleState state = _parseAppLifecycleMessage(window.initialLifecycleState);
    if (state != null) {
      handleAppLifecycleStateChanged(state);
    }
  }

  Future<String> _handleLifecycleMessage(String message) async {
    handleAppLifecycleStateChanged(_parseAppLifecycleMessage(message));
    return null;
  }

  static AppLifecycleState _parseAppLifecycleMessage(String message) {
    switch (message) {
      case 'AppLifecycleState.paused':
        return AppLifecycleState.paused;
      case 'AppLifecycleState.resumed':
        return AppLifecycleState.resumed;
      case 'AppLifecycleState.inactive':
        return AppLifecycleState.inactive;
      case 'AppLifecycleState.detached':
        return AppLifecycleState.detached;
    }
    return null;
  }
}