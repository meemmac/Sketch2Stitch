import 'package:cloud_firestore/cloud_firestore.dart';

/// Builds the target for the "Open in Maps" links.
///
/// A typed address alone is only ever a text search: Google Maps guesses,
/// and for the addresses people actually write here ("House 12, Road 5,
/// Dhanmondi") it routinely lands on the wrong road — or on a same-named
/// street in another city. When the party has a pinned [point] we hand Maps
/// the exact coordinates instead, so the marker sits on the real doorstep.
/// The address text is kept as the label so the pin still reads as a place
/// and not a bare number pair.
Uri buildMapsUri({GeoPoint? point, required String address}) {
  if (point != null) {
    final coords = '${point.latitude},${point.longitude}';
    return Uri.parse(
      'https://www.google.com/maps/search/?api=1'
      '&query=${Uri.encodeComponent(coords)}',
    );
  }
  return Uri.parse(
    'https://www.google.com/maps/search/?api=1'
    '&query=${Uri.encodeComponent(address)}',
  );
}
