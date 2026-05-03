import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fitness_timer/services/os/app_lifecycle_observer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppLifecycleObserver', () {
    test('stream emits state when didChangeAppLifecycleState is called',
        () async {
      final observer = AppLifecycleObserver();

      final future = observer.stream.first;
      observer.didChangeAppLifecycleState(AppLifecycleState.paused);

      expect(await future, AppLifecycleState.paused);
    });

    test('stream emits multiple states in order', () async {
      final observer = AppLifecycleObserver();
      final states = <AppLifecycleState>[];
      final sub = observer.stream.listen(states.add);

      observer.didChangeAppLifecycleState(AppLifecycleState.inactive);
      observer.didChangeAppLifecycleState(AppLifecycleState.paused);
      observer.didChangeAppLifecycleState(AppLifecycleState.resumed);

      await Future<void>.delayed(Duration.zero);
      sub.cancel();

      expect(states, [
        AppLifecycleState.inactive,
        AppLifecycleState.paused,
        AppLifecycleState.resumed,
      ]);
    });

    test('dispose() closes the stream without error', () {
      final observer = AppLifecycleObserver();
      expect(() => observer.dispose(), returnsNormally);
    });

    test(
        'calling didChangeAppLifecycleState after dispose does not throw '
        '(closed-controller guard)', () {
      final observer = AppLifecycleObserver();
      observer.dispose();

      // Must not throw StateError.
      expect(
        () => observer.didChangeAppLifecycleState(AppLifecycleState.resumed),
        returnsNormally,
      );
    });

    test('stream is a broadcast stream — multiple listeners are supported',
        () async {
      final observer = AppLifecycleObserver();

      // Collect events from both subscriptions.
      final future1 = observer.stream.first;
      final future2 = observer.stream.first;

      observer.didChangeAppLifecycleState(AppLifecycleState.paused);

      expect(await future1, AppLifecycleState.paused);
      expect(await future2, AppLifecycleState.paused);
    });
  });
}
