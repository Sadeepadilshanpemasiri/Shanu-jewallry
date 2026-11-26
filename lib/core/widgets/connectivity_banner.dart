import 'package:flutter/material.dart';

import '../localization/copy.dart';
import '../services/browser_capabilities.dart';

class ConnectivityBanner extends StatefulWidget {
  const ConnectivityBanner({super.key, required this.child, this.status});
  final Widget child;
  final Stream<bool>? status;
  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner> {
  late final _status = widget.status ?? watchBrowserOnline();

  @override
  Widget build(BuildContext context) => StreamBuilder<bool>(
    stream: _status,
    builder: (context, snapshot) {
      final colors = Theme.of(context).colorScheme;
      return Column(
        children: [
          if (snapshot.data == false)
            Material(
              color: colors.tertiaryContainer,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Semantics(
                    liveRegion: true,
                    child: Row(
                      children: [
                        Icon(
                          Icons.cloud_off,
                          color: colors.onTertiaryContainer,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Copy(
                            'Cached records may be available. Stock and order transactions need a connection.',
                            style: TextStyle(color: colors.onTertiaryContainer),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          else
            const SizedBox.shrink(),
          Expanded(child: widget.child),
        ],
      );
    },
  );
}
