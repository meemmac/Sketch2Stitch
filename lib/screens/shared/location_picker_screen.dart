import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../../widgets/top_feedback_banner.dart';

/// Free, no-API-key map picker built on flutter_map + OpenStreetMap-based
/// tiles. Returns a Firestore GeoPoint via Navigator.pop when confirmed.
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

  final TextEditingController _searchController = TextEditingController();
  bool _searching = false;
  List<Map<String, dynamic>> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _picked = widget.initialLocation != null
        ? ll.LatLng(widget.initialLocation!.latitude, widget.initialLocation!.longitude)
        : _dhakaFallback;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchLocation(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _searching = true);
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeQueryComponent(trimmed)}'
        '&format=json&addressdetails=1&limit=5',
      );
      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'com.example.sketch2stitch',
          'Accept-Language': 'en',
        },
      );

      if (response.statusCode == 200) {
        final List results = jsonDecode(response.body);
        setState(() {
          _searchResults = results.cast<Map<String, dynamic>>();
        });
        if (results.isEmpty && mounted) {
          AppFeedback.show(context, 'No results found for that location',
              isError: true);
        }
      } else {
        throw Exception('Search failed (${response.statusCode})');
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.show(context, 'Search error: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _selectResult(Map<String, dynamic> result) {
    final lat = double.parse(result['lat']);
    final lon = double.parse(result['lon']);
    final target = ll.LatLng(lat, lon);
    setState(() {
      _picked = target;
      _searchResults = [];
      _searchController.text = result['display_name'] ?? '';
    });
    _mapController.move(target, 16);
    FocusScope.of(context).unfocus();
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
        AppFeedback.show(context, 'Could not get current location: $e',
            isError: true);
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
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.example.sketch2stitch',
                maxZoom: 20,
                retinaMode: RetinaMode.isHighDensity(context),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 40),
            child: Icon(Icons.location_pin, size: 46, color: Color(0xFF6C9985)),
          ),
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: _searchLocation,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search for an address or area',
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    prefixIcon: const Icon(Icons.search, color: Colors.black54),
                    suffixIcon: _searching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : (_searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: Colors.black45),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchResults = []);
                                },
                              )
                            : IconButton(
                                icon: const Icon(Icons.arrow_forward, color: Color(0xFF6C9985)),
                                onPressed: () => _searchLocation(_searchController.text),
                              )),
                  ),
                ),
              ),
            ),
          ),
          if (_searchResults.isNotEmpty)
            Positioned(
              top: 66,
              left: 16,
              right: 16,
              child: Container(
                constraints: const BoxConstraints(maxHeight: 240),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.antiAlias,
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: _searchResults.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final result = _searchResults[index];
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.location_on_outlined, color: Color(0xFF6C9985)),
                        title: Text(
                          result['display_name'] ?? '',
                          style: const TextStyle(fontSize: 13),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => _selectResult(result),
                      );
                    },
                  ),
                ),
              ),
            ),
          if (_searchResults.isEmpty)
            Positioned(
              top: 66,
              left: 16,
              right: 16,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDFF2DF),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, size: 18, color: Colors.black87),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This location is used to estimate your delivery charge. '
                          'You can change it anytime from your profile.',
                          style: TextStyle(fontSize: 12, color: Colors.black87, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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