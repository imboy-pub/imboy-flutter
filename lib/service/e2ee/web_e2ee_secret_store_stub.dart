class WebE2eeSecretStore {
  Future<String?> read(String scope, String key, void Function() guard) =>
      throw UnsupportedError('Browser E2EE storage is unavailable');

  Future<void> write(
    String scope,
    String key,
    String value,
    void Function() guard,
  ) => throw UnsupportedError('Browser E2EE storage is unavailable');

  Future<void> writeAll(
    String scope,
    Map<String, String> values,
    void Function() guard,
  ) => throw UnsupportedError('Browser E2EE storage is unavailable');

  Future<void> delete(String scope, String key) =>
      throw UnsupportedError('Browser E2EE storage is unavailable');

  Future<void> purge(String prefix) =>
      throw UnsupportedError('Browser E2EE storage is unavailable');

  Future<void> requireEmpty() =>
      throw UnsupportedError('Browser E2EE storage is unavailable');
}
