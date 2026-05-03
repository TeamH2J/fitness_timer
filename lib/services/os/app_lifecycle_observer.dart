import 'dart:async';

import 'package:flutter/widgets.dart';

/// Observes [AppLifecycleState] changes and exposes them as a broadcast stream.
///
/// Register with [WidgetsBinding] via [attach], unregister via [detach].
/// Call [dispose] to close the stream when the observer is no longer needed.
class AppLifecycleObserver extends WidgetsBindingObserver {
  final StreamController<AppLifecycleState> _controller =
      StreamController<AppLifecycleState>.broadcast();

  /// Broadcast stream of app lifecycle state changes.
  Stream<AppLifecycleState> get stream => _controller.stream;

  /// Registers this observer with [WidgetsBinding].
  void attach() {
    WidgetsBinding.instance.addObserver(this);
  }

  /// Unregisters this observer from [WidgetsBinding].
  void detach() {
    WidgetsBinding.instance.removeObserver(this);
  }

  /// Closes the stream and unregisters from [WidgetsBinding].
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (!_controller.isClosed) {
      _controller.close();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_controller.isClosed) {
      _controller.add(state);
    }
  }
}
