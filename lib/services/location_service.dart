// ============================================================
// supabase_service.dart - re-export
// ============================================================
export 'auth_service.dart' show SupabaseService;

// ============================================================
// location_service.dart
// ============================================================
import 'package:geolocator/geolocator.dart';

class LocationService {
  /// Request location permission and get current position
  Future<Position?> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }

    if (permission == LocationPermission.deniedForever) return null;

    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  /// Check if user is within geofence radius of a location
  bool isWithinGeofence({
    required double userLat,
    required double userLng,
    required double targetLat,
    required double targetLng,
    double radiusMeters = 200,
  }) {
    final distance = Geolocator.distanceBetween(userLat, userLng, targetLat, targetLng);
    return distance <= radiusMeters;
  }

  /// Stream position updates for geofencing
  Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 50, // update every 50 meters
      ),
    );
  }
}