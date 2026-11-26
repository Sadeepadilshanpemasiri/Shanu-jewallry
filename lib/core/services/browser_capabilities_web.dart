import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

@JS('shopInstall')
external JSPromise<JSString> _shopInstall();

Future<String> promptInstall() async {
  try {
    return (await _shopInstall().toDart).toDart;
  } catch (_) {
    return 'manual';
  }
}

Stream<bool> watchBrowserOnline() {
  late final StreamController<bool> controller;
  final online = ((web.Event _) => controller.add(true)).toJS;
  final offline = ((web.Event _) => controller.add(false)).toJS;
  controller = StreamController<bool>(
    onListen: () {
      web.window.addEventListener('online', online);
      web.window.addEventListener('offline', offline);
      controller.add(web.window.navigator.onLine);
    },
    onCancel: () {
      web.window.removeEventListener('online', online);
      web.window.removeEventListener('offline', offline);
    },
  );
  return controller.stream.distinct();
}
