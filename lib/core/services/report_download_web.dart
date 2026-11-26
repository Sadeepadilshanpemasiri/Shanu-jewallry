import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

void downloadReport(Uint8List bytes, String filename, String mimeType) {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mimeType));
  final url = web.URL.createObjectURL(blob);
  final link = web.HTMLAnchorElement()
    ..href = url
    ..download = filename;
  web.document.body!.appendChild(link);
  link.click();
  link.remove();
  Timer(const Duration(seconds: 10), () => web.URL.revokeObjectURL(url));
}
