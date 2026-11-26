import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_providers.dart';

class OwnerIdleGuard extends ConsumerStatefulWidget {
  const OwnerIdleGuard({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<OwnerIdleGuard> createState() => _OwnerIdleGuardState();
}

class _OwnerIdleGuardState extends ConsumerState<OwnerIdleGuard>
    with WidgetsBindingObserver {
  static const _timeout = Duration(minutes: 15);
  Timer? _timer;
  DateTime _deadline = DateTime.now();
  bool _signingOut = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_onKey);
    _renew();
  }

  void _renew() {
    _deadline = DateTime.now().add(_timeout);
    _timer?.cancel();
    _timer = Timer(_timeout, _expire);
  }

  void _activity() {
    if (_signingOut) return;
    if (DateTime.now().isBefore(_deadline)) {
      _renew();
    } else {
      unawaited(_expire());
    }
  }

  bool _onKey(KeyEvent event) {
    _activity();
    return false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        !DateTime.now().isBefore(_deadline)) {
      unawaited(_expire());
    }
  }

  Future<void> _expire() async {
    if (!mounted || _signingOut) return;
    _signingOut = true;
    _timer?.cancel();
    try {
      await ref.read(authRepositoryProvider).signOut();
    } catch (_) {
      if (mounted) {
        _signingOut = false;
        _timer = Timer(const Duration(seconds: 10), _expire);
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    HardwareKeyboard.instance.removeHandler(_onKey);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: (_) => _activity(),
    onPointerSignal: (_) => _activity(),
    child: widget.child,
  );
}
