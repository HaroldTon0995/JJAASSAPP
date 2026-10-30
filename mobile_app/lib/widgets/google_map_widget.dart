import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../core/theme/app_theme.dart';
import '../services/tracking_service.dart';
import '../services/routing_service.dart';
import '../services/navigation_launcher.dart';

class GoogleMapWidget extends StatefulWidget {
  final double? destinationLat;
  final double? destinationLng;
  final String destinationAddress;
  final bool isDriverView;
  final String orderId;
  final String? customerName;
  final String? customerPhone;

  const GoogleMapWidget({
    super.key,
    this.destinationLat,
    this.destinationLng,
    required this.destinationAddress,
    required this.isDriverView,
    required this.orderId,
    this.customerName,
    this.customerPhone,
  });

  @override
  State<GoogleMapWidget> createState() => _GoogleMapWidgetState();
}

class _GoogleMapWidgetState extends State<GoogleMapWidget> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  StreamSubscription<Position>? _positionStreamSub;
  StreamSubscription<DriverLocation>? _trackingStreamSub;
  bool _hasRealLocation = false;

  // Manila fallback
  static const LatLng _defaultManila = LatLng(14.5995, 120.9842);

  LatLng get _destinationCoord {
    if (widget.destinationLat != null && widget.destinationLng != null) {
      return LatLng(widget.destinationLat!, widget.destinationLng!);
    }
    final hash = widget.destinationAddress.hashCode;
    final latOffset = (hash % 100) / 1000.0 - 0.05;
    final lngOffset = ((hash >> 4) % 100) / 1000.0 - 0.05;
    return LatLng(_defaultManila.latitude + latOffset, _defaultManila.longitude + lngOffset);
  }

  LatLng _driverCoord = _defaultManila;
  bool _isLoadingLocation = true;
  Timer? _mockMovementTimer;

  // OSRM road route & ETA states
  RouteInfo? _routeInfo;
  bool _isFetchingRoute = false;
  DateTime? _lastRouteFetchTime;

  @override
  void initState() {
    super.initState();
    _driverCoord = LatLng(
      _destinationCoord.latitude - 0.012,
      _destinationCoord.longitude - 0.012,
    );
    _initLocationTracking();
    _fetchRoadRoute();
  }

  @override
  void didUpdateWidget(covariant GoogleMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.destinationLat != widget.destinationLat ||
        oldWidget.destinationLng != widget.destinationLng ||
        oldWidget.orderId != widget.orderId) {
      _zoomToFitMarkers();
      _fetchRoadRoute();
    }
  }

  @override
  void dispose() {
    _trackingStreamSub?.cancel();
    _positionStreamSub?.cancel();
    _mockMovementTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _fetchRoadRoute() async {
    if (_isFetchingRoute) return;
    _isFetchingRoute = true;
    _lastRouteFetchTime = DateTime.now();

    try {
      final info = await RoutingService.getDrivingRoute(
        origin: _driverCoord,
        destination: _destinationCoord,
      );
      if (mounted) {
        setState(() {
          _routeInfo = info;
        });
      }
    } catch (e) {
      debugPrint('Error updating road route: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingRoute = false;
        });
      }
    }
  }

  void _triggerRouteUpdateIfNeeded() {
    // Throttle route fetches to at most once every 5 seconds
    if (_lastRouteFetchTime == null ||
        DateTime.now().difference(_lastRouteFetchTime!).inSeconds >= 5) {
      _fetchRoadRoute();
    }
  }

  Future<void> _initLocationTracking() async {
    if (!widget.isDriverView) {
      // Customer View: Listen to live Realtime stream from Supabase
      _trackingStreamSub = TrackingService.watch(widget.orderId).listen((loc) {
        if (mounted) {
          _hasRealLocation = true;
          _mockMovementTimer?.cancel();
          setState(() {
            _driverCoord = loc.position;
            _isLoadingLocation = false;
          });
          _zoomToFitMarkers();
          _triggerRouteUpdateIfNeeded();
        }
      });

      // Simulation fallback if driver is not actively publishing yet
      Timer(const Duration(seconds: 3), () {
        if (mounted && !_hasRealLocation) {
          _startMockDriverMovement();
          setState(() => _isLoadingLocation = false);
        }
      });
      return;
    }

    // Driver View: Read phone's real GPS hardware
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _startMockDriverMovement();
        setState(() => _isLoadingLocation = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _startMockDriverMovement();
          setState(() => _isLoadingLocation = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _startMockDriverMovement();
        setState(() => _isLoadingLocation = false);
        return;
      }

      Position pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      if (mounted) {
        setState(() {
          _currentPosition = pos;
          _driverCoord = LatLng(pos.latitude, pos.longitude);
          _isLoadingLocation = false;
        });
        _zoomToFitMarkers();
        _fetchRoadRoute();

        TrackingService.publish(
          orderId: widget.orderId,
          driverId: 'driver',
          lat: pos.latitude,
          lng: pos.longitude,
        );
      }

      // Stream continuous GPS movement
      _positionStreamSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen((Position position) {
        if (mounted) {
          setState(() {
            _currentPosition = position;
            _driverCoord = LatLng(position.latitude, position.longitude);
          });
          _zoomToFitMarkers();
          _triggerRouteUpdateIfNeeded();

          TrackingService.publish(
            orderId: widget.orderId,
            driverId: 'driver',
            lat: position.latitude,
            lng: position.longitude,
          );
        }
      });
    } catch (e) {
      debugPrint('Error initializing GPS tracking: $e');
      _startMockDriverMovement();
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  void _startMockDriverMovement() {
    double progress = 0.0;
    LatLng start = _driverCoord;
    LatLng end = _destinationCoord;

    _mockMovementTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted) return;
      progress += 0.05;
      if (progress >= 1.0) {
        progress = 1.0;
        timer.cancel();
      }

      setState(() {
        _driverCoord = LatLng(
          start.latitude + (end.latitude - start.latitude) * progress,
          start.longitude + (end.longitude - start.longitude) * progress,
        );
      });
      _zoomToFitMarkers();
      _triggerRouteUpdateIfNeeded();
    });
  }

  void _zoomToFitMarkers() {
    if (_mapController == null) return;
    try {
      LatLng driver = _driverCoord;
      LatLng destination = _destinationCoord;

      double minLat = min(driver.latitude, destination.latitude);
      double maxLat = max(driver.latitude, destination.latitude);
      double minLng = min(driver.longitude, destination.longitude);
      double maxLng = max(driver.longitude, destination.longitude);

      // Add minimum padding if coordinates are nearly identical
      if ((maxLat - minLat).abs() < 0.001) {
        maxLat += 0.002;
        minLat -= 0.002;
      }
      if ((maxLng - minLng).abs() < 0.001) {
        maxLng += 0.002;
        minLng -= 0.002;
      }

      LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(minLat - 0.003, minLng - 0.003),
        northeast: LatLng(maxLat + 0.003, maxLng + 0.003),
      );

      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
    } catch (e) {
      debugPrint('Safe bounds animation note: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingLocation) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      );
    }

    final Set<Marker> markers = {
      Marker(
        markerId: const MarkerId('driver_loc'),
        position: _driverCoord,
        infoWindow: InfoWindow(
          title: widget.isDriverView ? 'Your Delivery Vehicle' : 'Rider Location',
          snippet: _routeInfo != null
              ? '${_routeInfo!.formattedDistance} away • ${_routeInfo!.formattedDuration}'
              : 'En route',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ),
      Marker(
        markerId: const MarkerId('dest_loc'),
        position: _destinationCoord,
        infoWindow: InfoWindow(
          title: 'Delivery Pin Location',
          snippet: widget.destinationAddress,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    };

    // Use road polyline from OSRM, fallback to direct line
    final List<LatLng> polylinePoints = _routeInfo?.points ?? [_driverCoord, _destinationCoord];

    final Set<Polyline> polylines = {
      // Glow underlay polyline
      Polyline(
        polylineId: const PolylineId('route_glow'),
        points: polylinePoints,
        color: const Color(0xFF0284C7).withValues(alpha: 0.35),
        width: 8,
      ),
      // Road polyline
      Polyline(
        polylineId: const PolylineId('route_road'),
        points: polylinePoints,
        color: const Color(0xFF1D63B8),
        width: 5,
        geodesic: true,
      ),
    };

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: _driverCoord,
            zoom: 14.5,
          ),
          markers: markers,
          polylines: polylines,
          myLocationButtonEnabled: false,
          myLocationEnabled: widget.isDriverView && _currentPosition != null,
          zoomControlsEnabled: false,
          onMapCreated: (controller) {
            _mapController = controller;
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) _zoomToFitMarkers();
            });
          },
        ),

        // Grab-style Live Floating ETA & Distance Banner (Top Center)
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1D63B8).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.two_wheeler_rounded,
                    color: Color(0xFF1D63B8),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              widget.isDriverView ? 'En Route to Delivery Pin' : 'Rider on the Way',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _routeInfo != null
                            ? '${_routeInfo!.formattedDistance} remaining • ${_routeInfo!.formattedDuration}'
                            : 'Calculating live road route...',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0284C7),
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.isDriverView)
                  InkWell(
                    onTap: () {
                      NavigationLauncher.showNavigationSheet(
                        context,
                        lat: _destinationCoord.latitude,
                        lng: _destinationCoord.longitude,
                        customerName: widget.customerName ?? 'Customer',
                        address: widget.destinationAddress,
                        phone: widget.customerPhone,
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1D63B8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.near_me_rounded, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'Navigate',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
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

        // Map Re-center Floating Action Button
        Positioned(
          right: 14,
          bottom: 14,
          child: FloatingActionButton(
            backgroundColor: const Color(0xFF0F2B5C),
            mini: true,
            onPressed: _zoomToFitMarkers,
            child: const Icon(Icons.center_focus_strong_rounded, color: Colors.white, size: 20),
          ),
        ),
      ],
    );
  }
}
