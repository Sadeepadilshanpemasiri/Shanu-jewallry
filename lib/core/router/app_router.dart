import 'package:jewellery_business_manager/core/localization/copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/inventory/presentation/inventory_page.dart';
import '../../features/customers/presentation/customers_page.dart';
import '../../features/orders/presentation/orders_page.dart';
import '../../features/shipping/presentation/quick_ship_page.dart';
import '../../features/reports/presentation/reports_page.dart';
import '../../features/notifications/presentation/notifications_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../constants/app_copy.dart';

String? ownerRedirect({
  required String path,
  required bool waiting,
  required bool failed,
  required bool signedIn,
  String? returnTo,
}) {
  const destinations = {
    '/inventory',
    '/orders',
    '/customers',
    '/shipping',
    '/reports',
    '/notifications',
    '/settings',
  };
  final destination = destinations.contains(path) ? path : returnTo;
  if (!waiting && !failed && signedIn) {
    if (path == '/' || destinations.contains(path)) return null;
    return destinations.contains(destination) ? destination : '/';
  }
  final target = waiting
      ? '/splash'
      : failed
      ? '/session-error'
      : '/login';
  if (path == target) return null;
  return destinations.contains(destination)
      ? '$target?from=$destination'
      : target;
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(ownerSessionProvider, (_, _) => refresh.value++);
  final router = GoRouter(
    refreshListenable: refresh,
    redirect: (_, state) {
      final session = ref.read(ownerSessionProvider);
      return ownerRedirect(
        path: state.uri.path,
        returnTo: state.uri.queryParameters['from'],
        waiting: session.isLoading,
        failed: session.hasError,
        signedIn: session.asData?.value != null,
      );
    },
    routes: [
      _route('/', const DashboardPage()),
      _route('/inventory', const InventoryPage()),
      _route('/orders', const OrdersPage()),
      _route('/customers', const CustomersPage()),
      _route('/shipping', const QuickShipPage()),
      _route('/reports', const ReportsPage()),
      _route('/notifications', const NotificationsPage()),
      _route('/settings', const SettingsPage()),
      _route('/splash', const SplashPage()),
      _route('/login', const LoginPage()),
      _route('/session-error', const _SessionErrorPage()),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

GoRoute _route(String path, Widget child) => GoRoute(
  path: path,
  pageBuilder: (context, state) => CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 220),
    reverseTransitionDuration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 160),
    transitionsBuilder: (_, animation, _, page) => FadeTransition(
      opacity: animation.drive(CurveTween(curve: Curves.easeOut)),
      child: page,
    ),
  ),
);

class _SessionErrorPage extends ConsumerWidget {
  const _SessionErrorPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Copy(AppCopy.sessionError, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => ref.invalidate(ownerSessionProvider),
              child: const Copy(AppCopy.retry),
            ),
          ],
        ),
      ),
    ),
  );
}
