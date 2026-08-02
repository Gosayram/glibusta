class CacheEntry<T> {
  CacheEntry(this.value);
  final T value;
  final DateTime _createdAt = DateTime.now();
  bool isExpired(Duration ttl) => DateTime.now().difference(_createdAt) > ttl;
}
