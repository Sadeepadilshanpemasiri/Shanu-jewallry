import 'package:jewellery_business_manager/core/localization/copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/localization/language_provider.dart';
import 'core/widgets/connectivity_banner.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'core/constants/app_copy.dart';
import 'core/router/app_router.dart';
import 'core/services/firebase_config.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/widgets/premium_card.dart';
import 'features/auth/presentation/pages/splash_page.dart';
import 'features/auth/presentation/providers/auth_providers.dart';
import 'features/auth/presentation/widgets/owner_idle_guard.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  runApp(
    ProviderScope(
      child: _Bootstrap(initialization: FirebaseConfig.initialize()),
    ),
  );
}

class _Bootstrap extends ConsumerWidget {
  const _Bootstrap({required this.initialization});
  final Future<void> initialization;

  @override
  Widget build(BuildContext context, WidgetRef ref) => FutureBuilder<void>(
    future: initialization,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.done &&
          !snapshot.hasError) {
        return const JewelleryApp();
      }
      final locale =
          ref.watch(languageProvider).asData?.value ?? const Locale('en');
      return ShopLanguage(
        locale: locale,
        child: MaterialApp(
          title: AppCopy.name,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(
            Brightness.light,
            sinhala: locale.languageCode == "si",
          ),
          darkTheme: AppTheme.build(
            Brightness.dark,
            sinhala: locale.languageCode == "si",
          ),
          home: snapshot.hasError ? const _SetupPage() : const SplashPage(),
        ),
      );
    },
  );
}

class JewelleryApp extends ConsumerWidget {
  const JewelleryApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owner = ref.watch(ownerSessionProvider).asData?.value;
    final locale =
        ref.watch(languageProvider).asData?.value ?? const Locale('en');
    final engineLocale =
        GlobalMaterialLocalizations.delegate.isSupported(locale)
        ? locale
        : const Locale('en');
    return ShopLanguage(
      locale: locale,
      child: MaterialApp.router(
        locale: engineLocale,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const [Locale('en'), Locale('si')],
        title: AppCopy.name,
        debugShowCheckedModeBanner: false,
        routerConfig: ref.watch(appRouterProvider),
        builder: (context, child) {
          final page = child ?? const SizedBox.shrink();

          return ConnectivityBanner(
            child: owner == null ? page : OwnerIdleGuard(child: page),
          );
        },
        theme: AppTheme.build(
          Brightness.light,
          sinhala: locale.languageCode == "si",
        ),
        darkTheme: AppTheme.build(
          Brightness.dark,
          sinhala: locale.languageCode == "si",
        ),
        themeMode:
            ref.watch(appearanceProvider).asData?.value ?? ThemeMode.system,
      ),
    );
  }
}

class _SetupPage extends StatelessWidget {
  const _SetupPage();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: SizedBox(
          width: 420,
          child: PremiumCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BrandMark(),
                SizedBox(height: 16),
                Copy(
                  AppCopy.setupTitle,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                Copy(AppCopy.setupHint),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
