final class GeoPoint {
  const GeoPoint({
    required this.latitude,
    required this.longitude,
    this.accuracy,
  });
  final double latitude;
  final double longitude;
  final double? accuracy;
}

abstract interface class LocationCapability {
  Future<bool> requestPermission();
  Future<GeoPoint?> getCurrentLocation();
  Stream<GeoPoint> watchLocation({int intervalMs = 5000});
}
