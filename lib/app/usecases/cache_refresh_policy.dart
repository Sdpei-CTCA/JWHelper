class CacheRefreshPolicy {
  /// forceRefresh 时：跳过 SP 读取；网络失败才允许回退缓存
  static bool shouldReadDiskCache(bool forceRefresh) => !forceRefresh;

  /// forceRefresh 时：禁止因"空列表"回退旧缓存（空就是空）
  static bool shouldFallbackOnEmpty(bool forceRefresh) => !forceRefresh;
}
