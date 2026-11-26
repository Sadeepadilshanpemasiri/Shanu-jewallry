import 'package:flutter/material.dart';

import 'barcode_camera.dart';

class ScanCodePage extends StatefulWidget {
  const ScanCodePage({
    super.key,
    required this.title,
    required this.manualLabel,
  });
  final String title, manualLabel;

  @override
  State<ScanCodePage> createState() => _ScanCodePageState();
}

class _ScanCodePageState extends State<ScanCodePage> {
  final _input = TextEditingController();
  bool _finished = false;

  void _finish(String text) {
    final value = text.trim();
    if (!mounted ||
        _finished ||
        value.isEmpty ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    _finished = true;
    Navigator.of(context).pop(value);
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            BarcodeCamera(onCode: _finish),
            const SizedBox(height: 12),
            TextField(
              controller: _input,
              textInputAction: TextInputAction.done,
              autocorrect: false,
              onSubmitted: _finish,
              decoration: InputDecoration(labelText: widget.manualLabel),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => _finish(_input.text),
              child: const Text('Use code'),
            ),
          ],
        ),
      ),
    ),
  );
}
