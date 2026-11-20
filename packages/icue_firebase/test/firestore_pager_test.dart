import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:icue_firebase/icue_firebase.dart';

void main() {
  final rows = List.generate(7, (index) => index);
  Future<PagedResult<int>> fetch({
    required DocumentSnapshot<Map<String, dynamic>>? after,
    required int offset,
    required int limit,
  }) async => PagedResult(
    rows.skip(offset).take(limit).toList(),
    null,
    hasMore: offset + limit < rows.length,
  );

  test('walks pages forward and back', () async {
    final pager = FirestorePager<int>(pageSize: 3);
    await pager.load(fetch, count: () async => rows.length);
    expect(pager.items, [0, 1, 2]);
    expect(pager.total, 7);
    expect(pager.hasPrevious, isFalse);

    await pager.next();
    await pager.next();
    expect(pager.items, [6]);
    expect(pager.pageIndex, 2);
    expect(pager.hasNext, isFalse);

    await pager.previous();
    expect(pager.items, [3, 4, 5]);
    expect(pager.hasNext, isTrue);
  });

  test('append mode accumulates rows', () async {
    final pager = FirestorePager<int>(pageSize: 3);
    await pager.load(fetch);
    await pager.next(append: true);
    await pager.next(append: true);
    expect(pager.items, rows);
  });

  test('page size change restarts at the first page', () async {
    final pager = FirestorePager<int>(pageSize: 3);
    await pager.load(fetch);
    await pager.next();
    await pager.setPageSize(5);
    expect(pager.pageIndex, 0);
    expect(pager.items, [0, 1, 2, 3, 4]);
  });

  test('a newer load wins over a slower older one', () async {
    final pager = FirestorePager<int>(pageSize: 3);
    final slow = pager.load(({
      required after,
      required offset,
      required limit,
    }) async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return const PagedResult([99], null, hasMore: false);
    });
    await pager.load(fetch);
    await slow;
    expect(pager.items, [0, 1, 2]);
  });

  test('errors are kept, not thrown', () async {
    final pager = FirestorePager<int>();
    await pager.load(
      ({required after, required offset, required limit}) =>
          Future.error(StateError('offline')),
    );
    expect(pager.error, isA<StateError>());
    expect(pager.loading, isFalse);
  });

  test('the last page gives a total when the source cannot count', () async {
    final pager = FirestorePager<int>(pageSize: 3);
    await pager.load(fetch);
    expect(pager.total, isNull);
    await pager.next();
    await pager.next();
    expect(pager.total, 7);
  });

  test('an empty next page keeps the last real page', () async {
    final shrinking = [0, 1, 2, 3];
    final pager = FirestorePager<int>(pageSize: 3);
    await pager.load(
      ({required after, required offset, required limit}) async => PagedResult(
        shrinking.skip(offset).take(limit).toList(),
        null,
        hasMore: offset + limit < shrinking.length,
      ),
    );
    shrinking.removeLast();
    await pager.next();
    expect(pager.pageIndex, 0);
    expect(pager.items, [0, 1, 2]);
    expect(pager.hasNext, isFalse);
  });

  test('the count survives page moves made before it arrives', () async {
    final pager = FirestorePager<int>(pageSize: 3);
    final counted = Completer<int>();
    await pager.load(fetch, count: () => counted.future);
    await pager.next();
    counted.complete(7);
    await Future<void>.delayed(Duration.zero);
    expect(pager.total, 7);
  });

  test('a newer load drops the older count', () async {
    final pager = FirestorePager<int>(pageSize: 3);
    final stale = Completer<int>();
    await pager.load(fetch, count: () => stale.future);
    await pager.load(fetch, count: () async => 7);
    stale.complete(99);
    await Future<void>.delayed(Duration.zero);
    expect(pager.total, 7);
  });

  test('retry repeats the failed page, not the first', () async {
    var offline = false;
    final pager = FirestorePager<int>(pageSize: 3);
    await pager.load(({required after, required offset, required limit}) {
      if (offline) return Future.error(StateError('offline'));
      return fetch(after: after, offset: offset, limit: limit);
    });
    await pager.next();
    offline = true;
    await pager.next();
    expect(pager.error, isNotNull);
    expect(pager.items, [3, 4, 5]);
    offline = false;
    await pager.retry();
    expect(pager.error, isNull);
    expect(pager.pageIndex, 2);
    expect(pager.items, [6]);
  });
}
