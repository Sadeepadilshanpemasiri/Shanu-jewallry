import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeCamera extends StatefulWidget {
  const BarcodeCamera({super.key, required this.onCode});
  final ValueChanged<String> onCode;

  @override
  State<BarcodeCamera> createState() => _BarcodeCameraState();
}

class _BarcodeCameraState extends State<BarcodeCamera>
    with SingleTickerProviderStateMixin {
  final _camera = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    detectionTimeoutMs: 400,
  );
  late final _line = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  );
  String? _lastCode, _message;
  DateTime? _seen;
  bool _changing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _line.stop();
      _line.value = .5;
    } else if (!_line.isAnimating) {
      _line.repeat(reverse: true);
    }
  }

  void _detect(BarcodeCapture capture) {
    if (_changing || !mounted) return;
    final code = capture.barcodes
        .map((item) => item.rawValue?.trim())
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .firstOrNull;
    if (code == null) return;
    final now = DateTime.now();
    if (_lastCode == code &&
        _seen != null &&
        now.difference(_seen!) < const Duration(seconds: 2)) {
      return;
    }
    _lastCode = code;
    _seen = now;
    widget.onCode(code);
  }

  Future<void> _control(Future<void> Function() action, String error) async {
    setState(() {
      _changing = true;
      _message = null;
    });
    try {
      await action();
    } catch (_) {
      if (mounted) setState(() => _message = error);
    } finally {
      if (mounted) setState(() => _changing = false);
    }
  }

  @override
  void dispose() {
    _line.dispose();
    unawaited(_camera.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: AspectRatio(
            aspectRatio: 16 / 10,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: Colors.black,
                  child: MobileScanner(
                    controller: _camera,
                    onDetect: _detect,
                    errorBuilder: (_, _) => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Camera unavailable. Check browser permission or enter the code manually.',
                          style: TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
                ValueListenableBuilder<MobileScannerState>(
                  valueListenable: _camera,
                  builder: (_, state, _) => state.isRunning
                      ? IgnorePointer(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 32,
                            ),
                            child: AnimatedBuilder(
                              animation: _line,
                              builder: (_, _) => Align(
                                alignment: Alignment(0, _line.value * 2 - 1),
                                child: Container(
                                  height: 2,
                                  color: theme.colorScheme.primaryContainer,
                                ),
                              ),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
        ValueListenableBuilder<MobileScannerState>(
          valueListenable: _camera,
          builder: (_, state, _) => Wrap(
            spacing: 6,
            children: [
              TextButton.icon(
                onPressed: _changing
                    ? null
                    : () => _control(
                        state.isRunning
                            ? () => _camera.switchCamera()
                            : () => _camera.start(),
                        'Could not open another camera. Check browser permissions.',
                      ),
                icon: Icon(
                  state.isRunning
                      ? Icons.cameraswitch_outlined
                      : Icons.videocam_outlined,
                ),
                label: Text(state.isRunning ? 'Switch camera' : 'Retry camera'),
              ),
              if (state.torchState != TorchState.unavailable)
                TextButton.icon(
                  onPressed: _changing || !state.isRunning
                      ? null
                      : () => _control(
                          _camera.toggleTorch,
                          'The browser could not switch the flashlight.',
                        ),
                  icon: Icon(
                    state.torchState == TorchState.on
                        ? Icons.flash_off
                        : Icons.flash_on,
                  ),
                  label: Text(
                    state.torchState == TorchState.on
                        ? 'Flashlight off'
                        : 'Flashlight on',
                  ),
                ),
            ],
          ),
        ),
        if (_message case final message?)
          Text(message, style: TextStyle(color: theme.colorScheme.error)),
      ],
    );
  }
}
