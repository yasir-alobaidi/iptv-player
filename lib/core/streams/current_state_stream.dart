import 'dart:async';

/// Where something is now, then where it is after each change — for a
/// provider of state.
///
/// Every event is [current], read at the moment it is handed over, and
/// nothing is handed over or kept while the listener is paused; when it
/// comes back it is told [current] once.
///
/// Riverpod pauses a provider nobody watches, and a state stream forwarded
/// as it is (`yield state; yield* changes`) has by then one state already
/// on its way, with every later one queued behind it. The first screen to
/// watch again is handed that past. That is how the player, opened after
/// a cast had ended, was told "casting", closed itself and left the
/// channel playing with no picture (Phase 9 step 9, found by the soak).
///
/// The cost: changes made in one go arrive as the last of them, once.
/// That is right for what is drawn from state, and wrong for events that
/// each matter (listen to the stream itself for those).
Stream<T> currentThenChanges<T>(T Function() current, Stream<Object?> changes) {
  late final StreamController<T> controller;
  StreamSubscription<Object?>? source;
  var due = false;

  // Handed over in a microtask, so a listener that answers a state by
  // changing it is not inside the change that told it; and to a
  // synchronous controller, so nothing waits in it.
  void tell() {
    if (due) return;
    due = true;
    scheduleMicrotask(() {
      due = false;
      if (controller.isClosed ||
          !controller.hasListener ||
          controller.isPaused) {
        return;
      }
      controller.add(current());
    });
  }

  controller = StreamController<T>(
    sync: true,
    onListen: () {
      source = changes.listen(
        (_) => tell(),
        onError: controller.addError,
        onDone: controller.close,
      );
      tell();
    },
    onResume: tell,
    onCancel: () => source?.cancel(),
  );
  return controller.stream;
}
