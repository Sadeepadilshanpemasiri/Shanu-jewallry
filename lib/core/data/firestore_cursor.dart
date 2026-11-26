import 'package:cloud_firestore/cloud_firestore.dart';

import 'cursor_page.dart';

Future<CursorPage<T>> readFirestorePage<T>(
  Query<Map<String, dynamic>> query,
  T Function(QueryDocumentSnapshot<Map<String, dynamic>>) decode, {
  QueryDocumentSnapshot<Map<String, dynamic>>? after,
  bool cacheOnly = false,
}) async {
  const pageSize = 25;
  final window = after == null ? query : query.startAfterDocument(after);
  final snapshot = await window
      .limit(pageSize + 1)
      .get(
        GetOptions(source: cacheOnly ? Source.cache : Source.serverAndCache),
      );
  final documents = snapshot.docs.take(pageSize).toList();
  return CursorPage(
    documents.map(decode).toList(),
    fromCache: snapshot.metadata.isFromCache,
    next: snapshot.docs.length > pageSize
        ? () => readFirestorePage(
            query,
            decode,
            after: documents.last,
            cacheOnly: snapshot.metadata.isFromCache,
          )
        : null,
  );
}
