import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jewellery_business_manager/core/constants/app_copy.dart';
import 'package:jewellery_business_manager/features/auth/presentation/pages/login_page.dart';

void main() {
  testWidgets(
    'phone-size sign-in displays form validation and password controls',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 740));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: LoginPage())),
      );
      await tester.ensureVisible(find.text(AppCopy.signIn).last);
      await tester.tap(find.widgetWithText(FilledButton, AppCopy.signIn));
      await tester.pumpAndSettle();
      expect(find.text(AppCopy.emailError), findsOneWidget);
      expect(find.text(AppCopy.passwordError), findsOneWidget);
      await tester.tap(find.byTooltip(AppCopy.showPassword));
      await tester.pump();
      expect(find.byTooltip(AppCopy.hidePassword), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
