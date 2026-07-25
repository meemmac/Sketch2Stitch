import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:geolocator/geolocator.dart';

/// Free, no-API-key map picker built on flutter_map + OpenStreetMap tiles.
/// Returns a Firestore GeoPoint via Navigator.pop when the user confirms.
class LocationPickerScreen extends StatefulWidget {
  final GeoPoint? initialLocation;

  const LocationPickerScreen({super.key, this.initialLocation});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  static const _dhakaFallback = ll.LatLng(23.8103, 90.4125);

  late ll.LatLng _picked;
  final MapController _mapController = MapController();
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _picked = widget.initialLocation != null
        ? ll.LatLng(widget.initialLocation!.latitude, widget.initialLocation!.longitude)
        : _dhakaFallback;
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) throw Exception('Location services are off');

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        throw Exception('Location permission denied');
      }

      final pos = await Geolocator.getCurrentPosition();
      final target = ll.LatLng(pos.latitude, pos.longitude);
      setState(() => _picked = target);
      _mapController.move(target, 16);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not get current location: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _confirm() {
    Navigator.pop(context, GeoPoint(_picked.latitude, _picked.longitude));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pin your location'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _confirm,
            child: const Text('Confirm', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _picked,
              initialZoom: 15,
              onPositionChanged: (pos, hasGesture) {
                _picked = pos.center;
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                // Match this to your applicationId in android/app/build.gradle
                userAgentPackageName: 'com.example.sketch2stitch',
              ),
            ],
          ),
          // Fixed center pin — map moves underneath it. Simplest, least
          // buggy pattern on mobile since there's no marker drag-state.
          const Padding(
            padding: EdgeInsets.only(bottom: 40), // offsets for the pin's visual tip
            child: Icon(Icons.location_pin, size: 46, color: Color(0xFF6C9985)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.white,
        onPressed: _locating ? null : _useCurrentLocation,
        child: _locating
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6C9985)),
              )
            : const Icon(Icons.my_location, color: Color(0xFF6C9985)),
      ),
    );
  }
}