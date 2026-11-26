import 'package:flutter/material.dart';

import '../../../core/widgets/scan_code_page.dart';

class ProductScanner extends StatelessWidget {
  const ProductScanner({super.key});

  @override
  Widget build(BuildContext context) => const ScanCodePage(
    title: 'Scan product barcode',
    manualLabel: 'Enter SKU manually',
  );
}
