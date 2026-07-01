/// Re-subscribes to a Firestore snapshot stream if it errors. Firestore streams
/// terminate on error (e.g. a transient `permission-denied` right after sign-in,
/// before the auth token has propagated), and do not recover on their own. This
/// wrapper retries with a small backoff so the UI self-heals instead of showing
/// an error until the user reloads.
Stream<T> retryingSnapshots<T>(
  Stream<T> Function() source, {
  int maxAttempts = 8,
  Duration baseDelay = const Duration(milliseconds: 350),
}) async* {
  var attempt = 0;
  while (true) {
    try {
      yield* source();
      return; // source completed normally
    } catch (_) {
      attempt++;
      if (attempt >= maxAttempts) rethrow;
      await Future<void>.delayed(baseDelay * attempt);
    }
  }
}
