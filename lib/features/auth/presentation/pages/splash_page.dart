import 'package:jewellery_business_manager/core/localization/copy.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_copy.dart';
import '../../../../core/widgets/premium_card.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: .8, end: 1),
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 320),
          curve: Curves.easeOut,
          builder: (_, value, child) => Opacity(
            opacity: value,
            child: Transform.scale(scale: value, child: child),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrandMark(size: 78),
              const SizedBox(height: 16),
              Copy(
                AppCopy.name,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 22),
              const CircularProgressIndicator.adaptive(),
            ],
          ),
        ),
      ),
    ),
  );
}
