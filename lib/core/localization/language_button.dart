import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'copy.dart';
import 'language_provider.dart';

class LanguageButton extends ConsumerWidget {
  const LanguageButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => PopupMenuButton<Locale>(
    tooltip: context.tr('Language'),
    icon: const Icon(Icons.language_outlined),
    initialValue: ShopLanguage.of(context),
    itemBuilder: (_) => const [
      PopupMenuItem(value: Locale('en'), child: Text('English')),
      PopupMenuItem(value: Locale('si'), child: Text('සිංහල')),
    ],
    onSelected: (locale) async {
      try {
        await ref.read(languageProvider.notifier).select(locale);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Copy('Check your connection and try again.'),
            ),
          );
        }
      }
    },
  );
}
