import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/app_constants.dart';
import '../models/driver_location_model.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Timer? _gpsBroadcastTimer;
  bool _isBroadcasting = false;
  bool _useSimulation = false;

  double _simLatitude = 14.5995;
  double _simLongitude = 120.9842;
  double _simHeading = 45.0;

  bool get isBroadcasting => _isBroadcasting;
  bool get isSimulation => _useSimulation;

  bool get _isSupabaseConfigured =>
      AppConstants.supabaseUrl != 'YOUR_SUPABASE_PROJECT_URL' &&
      AppConstants.supabaseAnonKey != 'YOUR_SUPABASE_PROJECT_ANON_KEY';

  void startBroadcasting({
    required String driverId,
    required String driverName,
    String? orderId,
    bool forceSimulation = false,
  }) {
    if (_isBroadcasting) stopBroadcasting();
    _isBroadcasting = true;
    _useSimulation = forceSimulation;

    _broadcastCurrentLocation(driverId, driverName, orderId);

    _gpsBroadcastTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _broadcastCurrentLocation(driverId, driverName, orderId);
    });
  }

  void stopBroadcasting() {
    _gpsBroadcastTimer?.cancel();
    _gpsBroadcastTimer = null;
    _isBroadcasting = false;
  }

  Future<void> _broadcastCurrentLocation(
    String driverId,
    String driverName,
    String? orderId,
  ) async {
    double lat = _simLatitude;
    double lng = _simLongitude;
    double heading = _simHeading;
    double speed = 25.0;

    if (!_useSimulation && !kIsWeb) {
      try {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }

        if (permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse) {
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 4),
            ),
          );
          lat = position.latitude;
          lng = position.longitude;
          heading = position.heading;
          speed = position.speed;
        } else {
          _advanceSimulation();
          lat = _simLatitude;
          lng = _simLongitude;
        }
      } catch (e) {
        _advanceSimulation();
        lat = _simLatitude;
        lng = _simLongitude;
      }
    } else {
      _advanceSimulation();
      lat = _simLatitude;
      lng = _simLongitude;
    }

    final locationData = DriverLocationModel(
      driverId: driverId,
      driverName: driverName,
      orderId: orderId,
      latitude: lat,
      longitude: lng,
      heading: heading,
      speed: speed,
      updatedAt: DateTime.now(),
    );

    if (_isSupabaseConfigured) {
      try {
        final client = Supabase.instance.client;
        await client.from('driver_locations').upsert(
          locationData.toJson(),
          onConflict: 'driver_id',
        );
      } catch (e) {
        debugPrint('Failed to broadcast driver location to Supabase: $e');
      }
    }
  }

  void _advanceSimulation() {
    final random = Random();
    final deltaLat = (0.0003 + random.nextDouble() * 0.0002) * (random.nextBool() ? 1 : -0.5);
    final deltaLng = (0.0003 + random.nextDouble() * 0.0002) * (random.nextBool() ? 1 : -0.5);
    _simLatitude += deltaLat;
    _simLongitude += deltaLng;
    _simHeading = (_simHeading + 10) % 360;
  }

  Stream<List<DriverLocationModel>> streamDriverLocations() {
    if (!_isSupabaseConfigured) {
      return Stream.value([]);
    }

    try {
      final client = Supabase.instance.client;
      return client
          .from('driver_locations')
          .stream(primaryKey: ['driver_id'])
          .map((data) => data.map((json) => DriverLocationModel.fromJson(json)).toList());
    } catch (e) {
      debugPrint('Driver locations stream error: $e');
      return Stream.value([]);
    }
  }
}
