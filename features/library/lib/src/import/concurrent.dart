/// Runs [action] for every item with at most [workers] running at once, in list order of
/// starting. Stops starting new items after the first failure and rethrows it.
Future<void> forEachConcurrently<T>(
  List<T> items,
  int workers,
  Future<void> Function(T item) action,
) async {
  var next = 0;
  Object? failure;
  StackTrace? failureTrace;
  Future<void> worker() async {
    while (failure == null && next < items.length) {
      final item = items[next++];
      try {
        await action(item);
      } on Object catch (error, trace) {
        failure ??= error;
        failureTrace ??= trace;
      }
    }
  }

  await Future.wait([for (var index = 0; index < workers; index++) worker()]);
  if (failure != null) Error.throwWithStackTrace(failure!, failureTrace!);
}
