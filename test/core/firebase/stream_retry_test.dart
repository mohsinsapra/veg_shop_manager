import 'package:flutter_test/flutter_test.dart';
import 'package:veg_shop_manager/core/firebase/stream_retry.dart';

void main() {
  test('re-subscribes after an error and then yields data', () async {
    var calls = 0;
    final stream = retryingSnapshots<int>(
      () {
        calls++;
        if (calls == 1) return Stream<int>.error(Exception('permission-denied'));
        return Stream.fromIterable([1, 2, 3]);
      },
      baseDelay: const Duration(milliseconds: 1),
    );

    final result = await stream.take(3).toList();
    expect(result, [1, 2, 3]);
    expect(calls, greaterThanOrEqualTo(2)); // it retried
  });

  test('gives up after maxAttempts and surfaces the error', () async {
    final stream = retryingSnapshots<int>(
      () => Stream<int>.error(Exception('always')),
      maxAttempts: 3,
      baseDelay: const Duration(milliseconds: 1),
    );
    expect(stream.toList(), throwsA(isA<Exception>()));
  });
}
