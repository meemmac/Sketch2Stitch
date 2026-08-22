import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Distance helper used for rule-based delivery charge calculation
/// (see CartService.deliveryChargeFor and its callers).
class GeoUtils {
  /// Returns the great-circle distance in kilometers between two GeoPoints.
  static double distanceKm(GeoPoint a, GeoPoint b) {
    const earthRadiusKm = 6371.0;

    final dLat = _degToRad(b.latitude - a.latitude);
    final dLng = _degToRad(b.longitude - a.longitude);

    final lat1 = _degToRad(a.latitude);
    final lat2 = _degToRad(b.latitude);

    final h = sin(dLat / 2) * sin(dLat / 2) +
        sin(dLng / 2) * sin(dLng / 2) * cos(lat1) * cos(lat2);
    final c = 2 * atan2(sqrt(h), sqrt(1 - h));

    return earthRadiusKm * c;
  }

  static double _degToRad(double deg) => deg * (pi / 180);
}