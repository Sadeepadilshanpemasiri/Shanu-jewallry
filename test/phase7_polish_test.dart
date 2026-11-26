import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jewellery_business_manager/core/localization/copy.dart';
import 'package:jewellery_business_manager/core/widgets/connectivity_banner.dart';

void main() {
  testWidgets('Sinhala is selected and English remains the fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ShopLanguage(
        locale: Locale('si'),
        child: MaterialApp(
          home: Scaffold(
            body: Column(children: [Copy('New order'), Copy('Product SKU 42')]),
          ),
        ),
      ),
    );
    expect(find.text('නව ඇණවුම'), findsOneWidget);
    expect(find.text('Product SKU 42'), findsOneWidget);
  });

  testWidgets('offline banner preserves the current route state', (
    tester,
  ) async {
    final status = StreamController<bool>(sync: true);
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: ConnectivityBanner(
          status: status.stream,
          child: SizedBox(key: key, child: const Text('Route state')),
        ),
      ),
    );
    final original = key.currentContext!;
    status.add(false);
    await tester.pump();
    expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    expect(key.currentContext, same(original));
    status.add(true);
    await tester.pump();
    expect(find.byIcon(Icons.cloud_off), findsNothing);
    expect(key.currentContext, same(original));
    await tester.pumpWidget(const SizedBox.shrink());
    unawaited(status.close());
  });
}
