import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../core/theme/app_theme.dart';

class GoogleMapWidget extends StatefulWidget {
  final double? destinationLat;
  final double? destinationLng;
  final String destinationAddress;
  final bool isDriverView;
  final String orderId;

  const GoogleMapWidget({
    super.key,
    this.destinationLat,
    this.destinationLng,
    required this.destinationAddress,
    required this.isDriverView,
    required this.orderId,
  });

  @override
  State<GoogleMapWidget> createState() => _GoogleMapWidgetState();
}

class _GoogleMapWidgetState extends State<GoogleMapWidget> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  StreamSubscription<Position>? _positionStreamSub;
  
  // Default coordinates (Manila, Philippines) if none provided
  static const LatLng _defaultManila = LatLng(14.5995, 120.9842);
  
  LatLng get _destinationCoord {
    // Generate deterministic coordinates based on address to make it look realistic
    if (widget.destinationLat != null && widget.destinationLng != null) {
      return LatLng(widget.destinationLat!, widget.destinationLng!);
    }
    // Determinisitc coordinate offsets from Manila center using address hash
    final hash = widget.destinationAddress.hashCode;
    final latOffset = (hash % 100) / 1000.0 - 0.05;
    final lngOffset = ((hash >> 4) % 100) / 1000.0 - 0.05;
    return LatLng(_defaultManila.latitude + latOffset, _defaultManila.longitude + lngOffset);
  }

  LatLng _driverCoord = _defaultManila;
  bool _isLoadingLocation = true;
  Timer? _mockMovementTimer;

  @override
  void initState() {
    super.initState();
    _driverCoord = LatLng(_destinationCoord.latitude - 0.015, _destinationCoord.longitude - 0.015);
    _initLocationTracking();
  }

  @override
  void dispose() {
    _positionStreamSub?.cancel();
    _mockMovementTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initLocationTracking() async {
    if (!widget.isDriverView) {
      // For customers, we simulate the driver moving towards them
      _startMockDriverMovement();
      setState(() => _isLoadingLocation = false);
      return;
    }

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

      // Get current driver location
      Position pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      
      if (mounted) {
        setState(() {
          _currentPosition = pos;
          _driverCoord = LatLng(pos.latitude, pos.longitude);
          _isLoadingLocation = false;
        });
        _zoomToFitMarkers();
      }

      // Subscribe to real-time driver coordinates
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
        }
      });

    } catch (e) {
      debugPrint('Error initializing GPS tracking: $e');
      _startMockDriverMovement();
      if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  // Simulate driver movement on emulator or customer view
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
    });
  }

  void _zoomToFitMarkers() {
    if (_mapController == null) return;
    
    LatLng driver = _driverCoord;
    LatLng destination = _destinationCoord;

    double minLat = min(driver.latitude, destination.latitude);
    double maxLat = max(driver.latitude, destination.latitude);
    double minLng = min(driver.longitude, destination.longitude);
    double maxLng = max(driver.longitude, destination.longitude);

    LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(minLat - 0.002, minLng - 0.002),
      northeast: LatLng(maxLat + 0.002, maxLng + 0.002),
    );

    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
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
          title: widget.isDriverView ? 'Your Location' : 'Driver Location',
          snippet: 'Moving towards delivery point',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
      ),
      Marker(
        markerId: const MarkerId('dest_loc'),
        position: _destinationCoord,
        infoWindow: InfoWindow(
          title: 'Delivery Address',
          snippet: widget.destinationAddress,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    };

    final Set<Polyline> polylines = {
      Polyline(
        polylineId: const PolylineId('route'),
        points: [_driverCoord, _destinationCoord],
        color: AppTheme.primaryColor,
        width: 5,
        geodesic: true,
      ),
    };

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: _driverCoord,
            zoom: 14.0,
          ),
          markers: markers,
          polylines: polylines,
          myLocationButtonEnabled: false,
          myLocationEnabled: widget.isDriverView && _currentPosition != null,
          zoomControlsEnabled: true,
          onMapCreated: (controller) {
            _mapController = controller;
            _zoomToFitMarkers();
          },
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            backgroundColor: AppTheme.primaryColor,
            mini: true,
            onPressed: _zoomToFitMarkers,
            child: const Icon(Icons.center_focus_strong_rounded, color: Colors.white),
          ),
        ),
      ],
    );
  }
}
