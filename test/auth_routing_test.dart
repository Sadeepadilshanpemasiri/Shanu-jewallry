import 'package:flutter_test/flutter_test.dart';
import 'package:jewellery_business_manager/core/router/app_router.dart';

void main() {
  test('protected route requires the verified owner', () {
    expect(
      ownerRedirect(path: '/', waiting: false, failed: false, signedIn: false),
      '/login',
    );
    expect(
      ownerRedirect(path: '/', waiting: false, failed: false, signedIn: true),
      isNull,
    );
  });

  test('loading and failed session checks route to their own screens', () {
    expect(
      ownerRedirect(path: '/', waiting: true, failed: false, signedIn: false),
      '/splash',
    );
    expect(
      ownerRedirect(path: '/', waiting: false, failed: true, signedIn: false),
      '/session-error',
    );
    expect(
      ownerRedirect(
        path: '/session-error',
        waiting: false,
        failed: true,
        signedIn: false,
      ),
      isNull,
    );
  });
}
