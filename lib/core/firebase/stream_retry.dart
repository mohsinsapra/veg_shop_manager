import 'dart:async';

/// Re-subscribes to a Firestore snapshot stream when it errors. Firestore
/// streams terminate on error (e.g. a transient `permission-denied` right after
/// sign-in, before the auth token has propagated) and do not recover on their
/// own.
///
/// IMPORTANT: this cannot be done with `yield*` + try/catch, because `yield*`
/// forwards a source stream's ERROR events to the consumer instead of throwing
/// them into the generator. So we listen manually and re-subscribe on error.
Stream<T> retryingSnapshots<T>(
  Stream<T> Function() source, {
  int maxAttempts = 25,
  Duration baseDelay = const Duration(milliseconds: 400),
  Duration maxDelay = const Duration(seconds: 3),
}) {
  late StreamController<T> controller;
  StreamSubscription<T>? sub;
  var attempt = 0;
  var cancelled = false;

  void subscribe() {
    sub = source().listen(
      (data) {
        attempt = 0; // a successful event resets the backoff
        if (!controller.isClosed) controller.add(data);
      },
      onError: (Object error, StackTrace st) async {
        if (cancelled) return;
        await sub?.cancel();
        attempt++;
        if (attempt >= maxAttempts) {
          if (!controller.isClosed) controller.addError(error, st);
          return;
        }
        final delay = baseDelay * attempt;
        await Future<void>.delayed(delay > maxDelay ? maxDelay : delay);
        if (!cancelled && !controller.isClosed) subscribe();
      },
      onDone: () {
        if (!controller.isClosed) controller.close();
      },
    );
  }

  controller = StreamController<T>(
    onListen: subscribe,
    onCancel: () async {
      cancelled = true;
      await sub?.cancel();
    },
  );
  return controller.stream;
}
