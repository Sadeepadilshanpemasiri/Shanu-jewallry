import 'package:jewellery_business_manager/core/localization/copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/premium_card.dart';
import '../data/browser_push.dart';
import 'notification_providers.dart';

class BrowserPushPanel extends ConsumerStatefulWidget {
  const BrowserPushPanel({super.key});

  @override
  ConsumerState<BrowserPushPanel> createState() => _BrowserPushPanelState();
}

class _BrowserPushPanelState extends ConsumerState<BrowserPushPanel> {
  bool _supported = false, _enabled = false, _loading = true;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final service = ref.read(browserPushProvider);
    try {
      final supported = await service.supported();
      final enabled = supported && await service.enrolled();
      if (mounted) {
        setState(() {
          _supported = supported;
          _enabled = enabled;
          _message = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Could not check browser push. Try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _change() async {
    final service = ref.read(browserPushProvider);
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      if (_enabled) {
        await service.disable();
      } else {
        await service.enable();
      }
      if (mounted) setState(() => _enabled = !_enabled);
    } catch (error) {
      final message = error is PushFailure
          ? error.message
          : 'Could not update this browser’s push registration.';
      if (mounted) setState(() => _message = message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => PremiumCard(
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Copy('Browser push', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        if (_loading)
          const LinearProgressIndicator()
        else if (_supported) ...[
          Text(
            _enabled
                ? 'Push is enabled on this browser.'
                : 'Receive a push summary when the site is in the background.',
          ),
          TextButton(
            onPressed: _change,
            child: Text(_enabled ? 'Disable push here' : 'Enable push here'),
          ),
        ] else if (_message == null)
          const Text(
            'Web push requires a supported browser and a configured Firebase Hosting build.',
          ),
        if (_message case final message?) ...[
          Text(
            message,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          if (!_supported && !_loading)
            TextButton(
              onPressed: () {
                setState(() => _loading = true);
                _load();
              },
              child: const Copy('Retry'),
            ),
        ],
      ],
    ),
  );
}
