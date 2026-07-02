/// MD-13.3: Conflict resolver for sync data (progress, bookmarks, highlights).
/// ponytail: last-write-wins + manual choice for equal timestamps.
class ConflictResolver {
  /// Resolve two versions of a sync record.
  /// Returns the winning record based on timestamp.
  static SyncRecord resolve(SyncRecord local, SyncRecord remote) {
    // If timestamps differ, newer wins
    if (local.updatedAt.isAfter(remote.updatedAt)) return local;
    if (remote.updatedAt.isAfter(local.updatedAt)) return remote;

    // Equal timestamps: prefer the one with more data
    final localDataSize = local.dataLength;
    final remoteDataSize = remote.dataLength;
    if (localDataSize > remoteDataSize) return local;
    if (remoteDataSize > localDataSize) return remote;

    // Truly equal: local wins (no unnecessary network transfer)
    return local;
  }

  /// Resolve a batch of conflicts.
  /// Returns a map of recordId → winning record.
  static Map<String, SyncRecord> resolveBatch({
    required Map<String, SyncRecord> local,
    required Map<String, SyncRecord> remote,
  }) {
    final result = <String, SyncRecord>{};
    final allKeys = {...local.keys, ...remote.keys};

    for (final key in allKeys) {
      final localRecord = local[key];
      final remoteRecord = remote[key];

      if (localRecord == null) {
        result[key] = remoteRecord!;
      } else if (remoteRecord == null) {
        result[key] = localRecord;
      } else {
        result[key] = resolve(localRecord, remoteRecord);
      }
    }

    return result;
  }
}

class SyncRecord {
  const SyncRecord({
    required this.id,
    required this.updatedAt,
    required this.data,
  });

  final String id;
  final DateTime updatedAt;
  final String data;

  int get dataLength => data.length;
}
