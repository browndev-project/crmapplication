import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class LocationResult {
  final LatLng location;
  final String address;
  final String? city;
  final String? state;
  final String? country;
  final String? postcode;
  final String? suburb;
  final String? road;

  LocationResult({
    required this.location,
    required this.address,
    this.city,
    this.state,
    this.country,
    this.postcode,
    this.suburb,
    this.road,
  });
}

class _SuggestionItem {
  final String displayName;
  final double lat;
  final double lon;
  _SuggestionItem({required this.displayName, required this.lat, required this.lon});
}

class LocationPickerDialog extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;

  const LocationPickerDialog({
    super.key,
    this.initialLat,
    this.initialLng,
  });

  @override
  State<LocationPickerDialog> createState() => _LocationPickerDialogState();
}

class _LocationPickerDialogState extends State<LocationPickerDialog> {
  late MapController _mapController;
  LatLng _selectedLocation = const LatLng(22.7196, 75.8577);
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  bool _isSearching = false;
  bool _isConfirming = false;
  bool _isFetchingLocation = false;
  bool _isReverseGeocoding = false;

  // Current resolved address label
  String _addressLabel = '';

  // Autocomplete suggestions
  List<_SuggestionItem> _suggestions = [];
  Timer? _debounce;
  bool _showSuggestions = false;

  // Track if map is being dragged (center-pin style)
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    if (widget.initialLat != null && widget.initialLng != null) {
      _selectedLocation = LatLng(widget.initialLat!, widget.initialLng!);
      // Reverse geocode initial location
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _reverseGeocodeAndUpdate(_selectedLocation);
      });
    }

    _searchController.addListener(_onSearchChanged);
    _searchFocus.addListener(() {
      if (!_searchFocus.hasFocus) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) setState(() => _showSuggestions = false);
        });
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ─── GPS Current Location ─────────────────────────────────────────────────
  Future<void> _fetchCurrentLocation() async {
    setState(() => _isFetchingLocation = true);
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnackBar('Location services are disabled. Please enable GPS.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        _showSnackBar('Location permission denied forever. Please enable from Settings.');
        return;
      }
      if (permission == LocationPermission.denied) {
        _showSnackBar('Location permission denied');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 10)),
      ).timeout(const Duration(seconds: 12), onTimeout: () => throw TimeoutException('Location request timed out'));
      final newLoc = LatLng(pos.latitude, pos.longitude);
      if (mounted) {
        setState(() => _selectedLocation = newLoc);
        _mapController.move(newLoc, 16.0);
        _reverseGeocodeAndUpdate(newLoc);
      }
    } catch (e) {
      _showSnackBar('Could not get current location');
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  // ─── Autocomplete ─────────────────────────────────────────────────────────
  void _onSearchChanged() {
    final text = _searchController.text.trim();
    if (text.length < 3) {
      if (mounted) setState(() { _suggestions = []; _showSuggestions = false; });
      return;
    }
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () => _fetchSuggestions(text));
  }

  Future<void> _fetchSuggestions(String query) async {
    try {
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=5&addressdetails=1');
      final response = await http.get(url, headers: {'User-Agent': 'CRMApp/1.0'});
      if (response.statusCode == 200 && mounted) {
        final List results = json.decode(response.body);
        setState(() {
          _suggestions = results.map((r) => _SuggestionItem(
            displayName: r['display_name'] as String,
            lat: double.parse(r['lat'].toString()),
            lon: double.parse(r['lon'].toString()),
          )).toList();
          _showSuggestions = _suggestions.isNotEmpty;
        });
      }
    } catch (_) {}
  }

  void _selectSuggestion(_SuggestionItem item) {
    final newLoc = LatLng(item.lat, item.lon);
    _searchController.text = item.displayName.split(',').first;
    _searchFocus.unfocus();
    setState(() {
      _selectedLocation = newLoc;
      _suggestions = [];
      _showSuggestions = false;
      _addressLabel = item.displayName;
    });
    _mapController.move(newLoc, 15.0);
  }

  Future<void> _searchLocation() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() { _isSearching = true; _showSuggestions = false; });
    try {
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=1&addressdetails=1');
      final response = await http.get(url, headers: {'User-Agent': 'CRMApp/1.0'});
      if (response.statusCode == 200) {
        final List results = json.decode(response.body);
        if (results.isNotEmpty) {
          final lat = double.parse(results[0]['lat'].toString());
          final lon = double.parse(results[0]['lon'].toString());
          final newLocation = LatLng(lat, lon);
          setState(() {
            _selectedLocation = newLocation;
            _addressLabel = results[0]['display_name'] as String;
          });
          _mapController.move(newLocation, 15.0);
        } else {
          _showSnackBar('No results found');
        }
      }
    } catch (e) {
      _showSnackBar('Error searching location');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  // ─── Reverse Geocode ──────────────────────────────────────────────────────
  Future<LocationResult?> _reverseGeocode(LatLng location) async {
    try {
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?lat=${location.latitude}&lon=${location.longitude}&format=json&addressdetails=1');
      final response = await http.get(url, headers: {'User-Agent': 'CRMApp/1.0'});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final addressMap = data['address'] as Map<String, dynamic>? ?? {};
        return LocationResult(
          location: location,
          address: data['display_name'] ?? '',
          city: addressMap['city'] ?? addressMap['town'] ?? addressMap['village'] ?? addressMap['suburb'],
          state: addressMap['state'],
          country: addressMap['country'],
          postcode: addressMap['postcode'],
          suburb: addressMap['suburb'],
          road: addressMap['road'],
        );
      }
    } catch (e) {
      debugPrint('Reverse geocoding error: $e');
    }
    return null;
  }

  Future<void> _reverseGeocodeAndUpdate(LatLng location) async {
    if (_isReverseGeocoding) return;
    setState(() => _isReverseGeocoding = true);
    try {
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?lat=${location.latitude}&lon=${location.longitude}&format=json&addressdetails=1');
      final response = await http.get(url, headers: {'User-Agent': 'CRMApp/1.0'});
      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        setState(() {
          _addressLabel = data['display_name'] as String? ?? '';
        });
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _isReverseGeocoding = false);
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 820),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Select Location',
                      style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                  Row(
                    children: [
                      // GPS button
                      IconButton(
                        onPressed: _isFetchingLocation ? null : _fetchCurrentLocation,
                        icon: _isFetchingLocation
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.my_location, size: 20, color: Colors.blue),
                        tooltip: 'Use current location',
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.blue.withValues(alpha: 0.08),
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, size: 20),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.grey.withValues(alpha: 0.1),
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Search Bar ──────────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocus,
                            onSubmitted: (_) => _searchLocation(),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.search, size: 20),
                              hintText: 'Search area, landmark or address...',
                              hintStyle: TextStyle(color: Colors.grey.withValues(alpha: 0.6), fontSize: 13),
                              filled: true,
                              fillColor: isDark ? Colors.black26 : Colors.grey.withValues(alpha: 0.06),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          height: 46,
                          child: ElevatedButton(
                            onPressed: _isSearching ? null : _searchLocation,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              elevation: 0,
                            ),
                            child: _isSearching
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Search', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),

                    // ── Autocomplete Suggestions ───────────────────────────
                    if (_showSuggestions && _suggestions.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 8, offset: const Offset(0, 4))],
                          border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
                        ),
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: _suggestions.length,
                          separatorBuilder: (_, _) => Divider(height: 1, color: Colors.grey.withValues(alpha: 0.1)),
                          itemBuilder: (context, i) {
                            final s = _suggestions[i];
                            return InkWell(
                              onTap: () => _selectSuggestion(s),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                child: Row(
                                  children: [
                                    Icon(Icons.location_on_outlined, size: 16, color: Colors.grey[500]),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        s.displayName,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                    const SizedBox(height: 10),

                    // ── Address label ──────────────────────────────────────
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _addressLabel.isNotEmpty
                          ? Container(
                              key: const ValueKey('addr'),
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.location_on, size: 14, color: Colors.blue),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _isReverseGeocoding ? 'Fetching address...' : _addressLabel,
                                      style: TextStyle(fontSize: 11, color: isDark ? Colors.blue[200] : Colors.blue[800]),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : _isReverseGeocoding
                              ? Container(
                                  key: const ValueKey('loading'),
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Row(
                                    children: [
                                      SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5)),
                                      SizedBox(width: 8),
                                      Text('Fetching address...', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                    ],
                                  ),
                                )
                              : const SizedBox.shrink(key: ValueKey('empty')),
                    ),

                    const SizedBox(height: 8),

                    // ── Coordinates row ────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Tap map or drag to pinpoint',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                        ),
                        Text(
                          '${_selectedLocation.latitude.toStringAsFixed(5)}, ${_selectedLocation.longitude.toStringAsFixed(5)}',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // ── Map ────────────────────────────────────────────────
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Stack(
                          children: [
                            FlutterMap(
                              mapController: _mapController,
                              options: MapOptions(
                                initialCenter: _selectedLocation,
                                initialZoom: 15.0,
                                onTap: (tapPosition, point) {
                                  setState(() => _selectedLocation = point);
                                  _reverseGeocodeAndUpdate(point);
                                },
                                onPositionChanged: (camera, hasGesture) {
                                  if (hasGesture && _isDragging) {
                                    // Update location to map center while dragging
                                    setState(() => _selectedLocation = camera.center);
                                  }
                                },
                                onMapEvent: (event) {
                                  if (event is MapEventMoveStart) {
                                    setState(() => _isDragging = true);
                                  } else if (event is MapEventMoveEnd || event is MapEventFlingAnimationEnd) {
                                    final center = _mapController.camera.center;
                                    setState(() {
                                      _isDragging = false;
                                      _selectedLocation = center;
                                    });
                                    _reverseGeocodeAndUpdate(center);
                                  }
                                },
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  userAgentPackageName: 'com.trevioncrm.app',
                                ),
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: _selectedLocation,
                                      width: 40,
                                      height: 50,
                                      child: AnimatedScale(
                                        scale: _isDragging ? 1.3 : 1.0,
                                        duration: const Duration(milliseconds: 150),
                                        child: const Icon(Icons.location_on, size: 42, color: Colors.blue),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            // Zoom controls
                            Positioned(
                              top: 12,
                              left: 12,
                              child: Column(
                                children: [
                                  _buildMapControlButton(
                                    icon: Icons.add,
                                    onPressed: () => _mapController.move(
                                        _mapController.camera.center, _mapController.camera.zoom + 1),
                                  ),
                                  const SizedBox(height: 6),
                                  _buildMapControlButton(
                                    icon: Icons.remove,
                                    onPressed: () => _mapController.move(
                                        _mapController.camera.center, _mapController.camera.zoom - 1),
                                  ),
                                ],
                              ),
                            ),

                            // Current location button (bottom right)
                            Positioned(
                              bottom: 12,
                              right: 12,
                              child: FloatingActionButton.small(
                                onPressed: _isFetchingLocation ? null : _fetchCurrentLocation,
                                backgroundColor: Colors.white,
                                child: _isFetchingLocation
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Icon(Icons.my_location, color: Colors.blue, size: 20),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Footer ──────────────────────────────────────────────────────
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: const Text('CANCEL', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isConfirming ? null : () async {
                        final navigator = Navigator.of(context);
                        setState(() => _isConfirming = true);
                        final result = await _reverseGeocode(_selectedLocation);
                        setState(() => _isConfirming = false);
                        if (mounted) navigator.pop(result);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: _isConfirming
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('CONFIRM LOCATION', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapControlButton({required IconData icon, required VoidCallback onPressed}) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: IconButton(
        icon: Icon(icon, size: 18, color: Colors.black87),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
      ),
    );
  }
}
