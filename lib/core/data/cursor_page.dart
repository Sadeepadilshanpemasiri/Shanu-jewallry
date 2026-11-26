typedef PageLoader<T> = Future<CursorPage<T>> Function();

class CursorPage<T> {
  const CursorPage(this.items, {this.next, this.fromCache = false});

  final bool fromCache;

  final List<T> items;
  final PageLoader<T>? next;
}
