import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/stopwatch_session.dart';
import '../services/os/stopwatch_os_bridge.dart';
import '../services/stopwatch/stopwatch_engine.dart';
import 'database_provider.dart';
import 'os_provider.dart';

// ---------------------------------------------------------------------------
// stopwatchOsBridgeProvider
// ---------------------------------------------------------------------------

final stopwatchOsBridgeProvider = Provider<StopwatchOsBridge>((ref) {
  final bridge = StopwatchOsBridge(
    wakelock: ref.read(wakelockManagerProvider),
    foregroundService: ref.read(foregroundServiceControllerProvider),
  );
  ref.onDispose(bridge.detach);
  return bridge;
});

// ---------------------------------------------------------------------------
// StopwatchEngineNotifier + stopwatchEngineProvider
// ---------------------------------------------------------------------------

class StopwatchEngineNotifier extends StateNotifier<StopwatchSnapshot> {
  StopwatchEngineNotifier({
    required StopwatchOsBridge bridge,
    required Ref ref,
  })  : _bridge = bridge,
        _ref = ref,
        super(StopwatchSnapshot.initial) {
    _engine = StopwatchEngine();
    _snapshotSub = _engine.snapshots.listen((snapshot) {
      state = snapshot;
    });
  }

  final StopwatchOsBridge _bridge;
  final Ref _ref;
  late final StopwatchEngine _engine;
  StreamSubscription<StopwatchSnapshot>? _snapshotSub;

  void start() {
    _engine.start();
    _bridge.attach(_engine.snapshots);
  }

  void stop() {
    _engine.stop();
  }

  void lap() {
    _engine.lap();
  }

  Future<void> reset() async {
    final session = _engine.reset();
    _bridge.detach();
    if (session != null) {
      try {
        await _ref.read(databaseServiceProvider).insertStopwatchSession(session);
      } catch (e, st) {
        // Session data lost silently — acceptable per OOS-2 scope.
        debugPrint('StopwatchEngineNotifier: failed to save session: $e\n$st');
      }
    }
  }

  @override
  void dispose() {
    _snapshotSub?.cancel();
    _engine.dispose();
    _bridge.detach();
    super.dispose();
  }
}

final stopwatchEngineProvider =
    StateNotifierProvider<StopwatchEngineNotifier, StopwatchSnapshot>((ref) {
  return StopwatchEngineNotifier(
    bridge: ref.read(stopwatchOsBridgeProvider),
    ref: ref,
  );
});

// ---------------------------------------------------------------------------
// mergedHistoryProvider
// ---------------------------------------------------------------------------

final mergedHistoryProvider = FutureProvider<List<HistoryEntry>>((ref) async {
  return ref.watch(databaseServiceProvider).getMergedHistory(limit: 100);
});
