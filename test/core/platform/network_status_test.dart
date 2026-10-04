import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/platform/network_status.dart';

/// The system's word, said when the test says.
final class _System implements SystemNetwork {
  final _states = StreamController<Reachability>.broadcast();

  void say(Reachability state) => _states.add(state);

  @override
  Stream<Reachability> watch() => _states.stream;
}

void main() {
  late _System system;
  late NetworkStatus status;
  late List<bool> told;

  /// A status on [system], watched; [told] gathers what it says.
  void start(FakeAsync async) {
    system = _System();
    status = NetworkStatus(system);
    told = [];
    status.watch().listen(told.add);
    async.flushMicrotasks();
  }

  void say(FakeAsync async, Reachability state) {
    system.say(state);
    async.flushMicrotasks();
  }

  test('the system says offline: offline once it has lasted 3 s; back '
      'online at once', () {
    fakeAsync((async) {
      start(async);
      say(async, Reachability.online);
      say(async, Reachability.offline);
      async.elapse(const Duration(milliseconds: 2900));
      expect(status.offline, isFalse);
      async.elapse(const Duration(milliseconds: 100));
      expect(status.offline, isTrue);

      say(async, Reachability.online);
      expect(status.offline, isFalse);
      expect(told, [false, true, false]);
    });
  });

  test('a moment offline, as a Wi-Fi roam goes through connecting, is '
      'never told', () {
    fakeAsync((async) {
      start(async);
      say(async, Reachability.offline);
      async.elapse(const Duration(seconds: 1));
      say(async, Reachability.online);
      async.elapse(const Duration(seconds: 10));
      expect(told, [false]);
    });
  });

  test('the system says online: a source that gives no answer is down, '
      'not the internet', () {
    fakeAsync((async) {
      start(async);
      say(async, Reachability.online);
      status.sourceUnanswered();
      async.elapse(const Duration(seconds: 10));
      expect(status.offline, isFalse);
    });
  });

  test('the system says offline but a source answers (a provider at '
      'home): online; a new word from the system forgets that', () {
    fakeAsync((async) {
      start(async);
      say(async, Reachability.offline);
      status.sourceAnswered();
      async.elapse(const Duration(seconds: 10));
      expect(status.offline, isFalse);

      // The laptop moves to another network, with no internet either.
      say(async, Reachability.online);
      say(async, Reachability.offline);
      async.elapse(const Duration(seconds: 3));
      expect(status.offline, isTrue);
      status.sourceAnswered();
      expect(status.offline, isFalse);
    });
  });

  test("the system can't say: offline after a request with no answer at "
      'all, until one is answered', () {
    fakeAsync((async) {
      start(async);
      say(async, Reachability.unknown);
      expect(status.offline, isFalse);

      status.sourceUnanswered();
      async.elapse(const Duration(seconds: 3));
      expect(status.offline, isTrue);
      status.sourceUnanswered();
      expect(status.offline, isTrue);

      status.sourceAnswered();
      expect(status.offline, isFalse);
      async.flushMicrotasks();
      expect(told, [false, true, false]);
    });
  });

  test('no system at all: unknown, so the sources decide', () {
    fakeAsync((async) {
      final status = NetworkStatus(const NoSystemNetwork());
      async.flushMicrotasks();
      expect(status.offline, isFalse);
      status.sourceUnanswered();
      async.elapse(const Duration(seconds: 3));
      expect(status.offline, isTrue);
      unawaited(status.dispose());
      async.flushMicrotasks();
    });
  });

  test('watch says the state now first, then each change; dispose ends '
      'it', () {
    fakeAsync((async) {
      start(async);
      say(async, Reachability.offline);
      async.elapse(const Duration(seconds: 3));
      final late = <bool>[];
      var done = false;
      status.watch().listen(late.add, onDone: () => done = true);
      async.flushMicrotasks();
      expect(late, [true]);

      unawaited(status.dispose());
      async.flushMicrotasks();
      expect(done, isTrue);
      // Nothing after it is disposed.
      say(async, Reachability.online);
      expect(late, [true]);
    });
  });
}
