import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class PremiumCard extends StatelessWidget {
  const PremiumCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 64});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: const Color(0xff252018),
      border: Border.all(color: AppTheme.gold.withValues(alpha: .6)),
      borderRadius: BorderRadius.circular(size * .29),
    ),
    child: Icon(Icons.diamond_outlined, color: AppTheme.gold, size: size * .52),
  );
}
