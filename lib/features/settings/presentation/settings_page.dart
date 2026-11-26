import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/copy.dart';
import '../../../core/localization/language_button.dart';
import '../../../core/services/browser_capabilities.dart';
import '../../../core/services/report_download.dart';
import '../../inventory/presentation/recycle_bin_page.dart';
import 'activity_page.dart';
import '../../notifications/presentation/reminder_settings_sheet.dart';
import '../data/shop_backup.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _exporting = false;

  Future<void> _install() async {
    final outcome = await promptInstall();
    if (!mounted || outcome == 'accepted' || outcome == 'dismissed') return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Copy('Install app'),
        content: Copy(
          outcome == 'installed'
              ? 'The app is open in standalone mode.'
              : 'Open the browser menu and choose Install app or Add to Home Screen. On iPhone, use Safari’s Share menu.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Copy('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _backup() async {
    setState(() => _exporting = true);
    try {
      final bytes = await exportShopBackup(FirebaseFirestore.instance);
      if (!mounted) return;
      final day = DateTime.now().toIso8601String().split('T').first;
      downloadReport(bytes, 'jewellery-backup-$day.json', 'application/json');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Copy(
              'Could not download the backup. Check your connection.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Copy('Settings'),
      leading: BackButton(onPressed: () => context.go('/')),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 660),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const ListTile(
              leading: Icon(Icons.language_outlined),
              title: Copy('Language'),
              trailing: LanguageButton(),
            ),
            ListTile(
              leading: const Icon(Icons.install_mobile_outlined),
              title: const Copy('Install app'),
              onTap: _install,
            ),
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Copy('Reminder rules'),
              onTap: () => openReminderSettings(context),
            ),
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: const Copy('Download data backup'),
              subtitle: const Copy(
                'Includes business records in JSON. Keep the file private.',
              ),
              enabled: !_exporting,
              onTap: _exporting ? null : _backup,
            ),
            if (_exporting) const LinearProgressIndicator(),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Activity'),
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute(builder: (_) => const ActivityPage()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: const Text('Product recycle bin'),
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute(builder: (_) => const RecycleBinPage()),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
