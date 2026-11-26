import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jewellery_business_manager/core/data/cursor_page.dart';
import 'package:jewellery_business_manager/core/widgets/cursor_catalog.dart';

Widget catalog(
  PageLoader<String> first, {
  Object revision = 0,
  AsyncValue<List<String>>? full,
}) => MaterialApp(
  home: Scaffold(
    body: CursorCatalog<String>(
      revision: revision,
      recordId: (record) => record,
      first: first,
      full: full,
      errorText: (_) => 'Could not load records.',
      builder: (rows, footer, refresh) => Column(
        children: [
          for (final row in rows) Text(row),
          ?footer,
          TextButton(onPressed: refresh, child: const Text('Refresh')),
        ],
      ),
    ),
  ),
);

void main() {
  testWidgets('cached pages remain labeled until a server refresh', (
    tester,
  ) async {
    var online = false;
    Future<CursorPage<String>> first() async => online
        ? const CursorPage(['Server record'])
        : CursorPage(
            ['Cached first'],
            fromCache: true,
            next: () async =>
                const CursorPage(['Cached second'], fromCache: true),
          );

    await tester.pumpWidget(catalog(first));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();

    expect(find.text('Cached first'), findsOneWidget);
    expect(find.text('Cached second'), findsOneWidget);
    expect(
      find.text('Showing cached records. The list may be incomplete.'),
      findsOneWidget,
    );

    online = true;
    await tester.tap(find.text('Check for updates'));
    await tester.pumpAndSettle();
    expect(find.text('Server record'), findsOneWidget);
    expect(find.text('Cached second'), findsNothing);
    expect(find.text('Check for updates'), findsNothing);
  });

  testWidgets('an empty cache differs from an empty server list', (
    tester,
  ) async {
    await tester.pumpWidget(
      catalog(() async => const CursorPage([], fromCache: true)),
    );
    await tester.pumpAndSettle();
    expect(find.text('No records are cached on this device.'), findsOneWidget);
    expect(find.text('Check for updates'), findsOneWidget);
  });

  testWidgets('retries a failed page and appends unique records', (
    tester,
  ) async {
    var attempts = 0;
    Future<CursorPage<String>> second() async {
      if (++attempts == 1) throw StateError('offline');
      return const CursorPage(['A', 'B']);
    }

    await tester.pumpWidget(
      catalog(() async => CursorPage(['A'], next: second)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsNothing);

    await tester.tap(find.text('Could not load records. Retry'));
    await tester.pumpAndSettle();
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('Load more'), findsNothing);
  });

  testWidgets('refresh supersedes a pending page', (tester) async {
    final pending = Completer<CursorPage<String>>();
    var firstReads = 0;
    await tester.pumpWidget(
      catalog(() async {
        if (++firstReads == 1) {
          return CursorPage(['Old'], next: () => pending.future);
        }
        return const CursorPage(['New']);
      }),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Load more'));
    await tester.pump();
    await tester.tap(find.text('Refresh'));
    await tester.pumpAndSettle();
    pending.complete(const CursorPage(['Stale']));
    await tester.pumpAndSettle();
    expect(find.text('New'), findsOneWidget);
    expect(find.text('Old'), findsNothing);
    expect(find.text('Stale'), findsNothing);
  });

  testWidgets('full results replace the page while filtering', (tester) async {
    Future<CursorPage<String>> first() async => const CursorPage(['First']);
    await tester.pumpWidget(catalog(first));
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      catalog(first, full: const AsyncData(['Beyond first page'])),
    );
    expect(find.text('Beyond first page'), findsOneWidget);
    expect(find.text('First'), findsNothing);

    await tester.pumpWidget(catalog(first));
    expect(find.text('First'), findsOneWidget);
  });
}
