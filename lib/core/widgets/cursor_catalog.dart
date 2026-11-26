import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/cursor_page.dart';

class CursorCatalog<T> extends StatefulWidget {
  const CursorCatalog({
    super.key,
    required this.first,
    required this.revision,
    required this.recordId,
    required this.errorText,
    required this.builder,
    this.full,
    this.refreshFull,
  });

  final PageLoader<T> first;
  final Object revision;
  final String Function(T) recordId;
  final String Function(Object) errorText;
  final AsyncValue<List<T>>? full;
  final VoidCallback? refreshFull;
  final Widget Function(
    List<T> rows,
    Widget? footer,
    Future<void> Function() refresh,
  )
  builder;

  @override
  State<CursorCatalog<T>> createState() => _CursorCatalogState<T>();
}

class _CursorCatalogState<T> extends State<CursorCatalog<T>> {
  List<T> _rows = [];
  PageLoader<T>? _next;
  Object? _error;
  Future<void> Function()? _retry;
  bool _loading = false;
  bool _initialized = false;
  bool _fromCache = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    if (widget.full == null) _reset();
  }

  @override
  void didUpdateWidget(CursorCatalog<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision) {
      _generation++;
      _rows = [];
      _next = null;
      _initialized = false;
      _fromCache = false;
      _loading = false;
      _error = null;
    }
    if (widget.full == null && !_initialized && !_loading && _error == null) {
      _reset();
    }
  }

  Future<void> _reset() => _load(widget.first, replace: true);

  Future<void> _load(PageLoader<T> loader, {bool replace = false}) async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      _retry = () => _load(loader, replace: replace);
    });
    try {
      final page = await loader();
      if (!mounted || generation != _generation) return;
      setState(() {
        _rows = [
          ...{
            if (!replace)
              for (final row in _rows) widget.recordId(row): row,
            for (final row in page.items) widget.recordId(row): row,
          }.values,
        ];
        _next = page.next;
        _fromCache = (!replace && _fromCache) || page.fromCache;
        _initialized = true;
      });
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _error = error);
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _refresh() async {
    if (widget.full != null) {
      widget.refreshFull?.call();
    } else {
      await _reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final full = widget.full;
    final error = full == null ? _error : full.error;
    final loading = full == null ? _loading : full.isLoading;
    final next = full == null ? _next : null;
    final rows = full == null ? _rows : full.value ?? [];
    final Widget? footer;
    if (loading) {
      footer = const Center(child: CircularProgressIndicator());
    } else if (error != null) {
      footer = Center(
        child: TextButton(
          onPressed: full == null ? _retry : _refresh,
          child: Text('${widget.errorText(error)} Retry'),
        ),
      );
    } else if (next != null) {
      footer = Center(
        child: OutlinedButton(
          onPressed: () => _load(next),
          child: const Text('Load more'),
        ),
      );
    } else {
      footer = null;
    }
    if (full == null && _fromCache) {
      return widget.builder(
        rows,
        Column(
          children: [
            Text(
              rows.isEmpty
                  ? 'No records are cached on this device.'
                  : 'Showing cached records. The list may be incomplete.',
              textAlign: TextAlign.center,
            ),
            if (!loading && error == null)
              TextButton(
                onPressed: _refresh,
                child: const Text('Check for updates'),
              ),
            ?footer,
          ],
        ),
        _refresh,
      );
    }
    return widget.builder(rows, footer, _refresh);
  }
}
