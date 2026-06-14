abstract interface class NotificationCapability {
  Future<bool> requestPermission();
  Future<void> show({
    required String title,
    required String body,
    String? payload,
  });
  Future<void> cancel(int id);
  Future<void> cancelAll();
  Stream<String> get onTap;
}
