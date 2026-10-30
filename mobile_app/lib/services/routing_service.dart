import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class RouteInfo {
  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;

  const RouteInfo({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  String get formattedDistance {
    if (distanceMeters < 1000) {
      return '${distanceMeters.toStringAsFixed(0)} m';
    }
    return '${(distanceMeters / 1000.0).toStringAsFixed(1)} km';
  }

  String get formattedDuration {
    final mins = (durationSeconds / 60.0).round();
    if (mins <= 1) return '~1 min';
    if (mins < 60) return '~$mins mins';
    final hours = mins ~/ 60;
    final remMins = mins % 60;
    return '~$hours hr ${remMins > 0 ? '$remMins mins' : ''}';
  }
}

class RoutingService {
  static final Map<String, RouteInfo> _routeCache = {};

  /// Fetches the real road-snapped driving polyline, distance, and duration between
  /// [origin] and [destination] using the Open Source Routing Machine (OSRM).
  static Future<RouteInfo> getDrivingRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    // Generate rounded cache key to reduce duplicate calls for small movements
    final key =
        '${origin.latitude.toStringAsFixed(4)},${origin.longitude.toStringAsFixed(4)}->'
        '${destination.latitude.toStringAsFixed(4)},${destination.longitude.toStringAsFixed(4)}';

    if (_routeCache.containsKey(key)) {
      return _routeCache[key]!;
    }

    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${origin.longitude},${origin.latitude};'
        '${destination.longitude},${destination.latitude}'
        '?overview=full&geometries=geojson',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final routes = data['routes'] as List?;

        if (routes != null && routes.isNotEmpty) {
          final route = routes[0];
          final distance = (route['distance'] as num?)?.toDouble() ?? 0.0;
          final duration = (route['duration'] as num?)?.toDouble() ?? 0.0;
          final geometry = route['geometry'] as Map<String, dynamic>?;
          final coords = geometry?['coordinates'] as List?;

          if (coords != null && coords.isNotEmpty) {
            final points = coords.map<LatLng>((c) {
              final lng = (c[0] as num).toDouble();
              final lat = (c[1] as num).toDouble();
              return LatLng(lat, lng);
            }).toList();

            final info = RouteInfo(
              points: points,
              distanceMeters: distance,
              durationSeconds: duration,
            );
            _routeCache[key] = info;
            return info;
          }
        }
      }
    } catch (e) {
      debugPrint('RoutingService: OSRM route fetch failed or timed out: $e');
    }

    // Fallback: Straight line between origin and destination
    return RouteInfo(
      points: [origin, destination],
      distanceMeters: _calculateHaversineDistance(origin, destination),
      durationSeconds:
          (_calculateHaversineDistance(origin, destination) /
          8.33), // assume ~30km/h
    );
  }

  static double _calculateHaversineDistance(LatLng p1, LatLng p2) {
    const double earthRadius = 6371000; // in meters
    final dLat = _toRadians(p2.latitude - p1.latitude);
    final dLng = _toRadians(p2.longitude - p1.longitude);

    final a =
        (dLat / 2).abs() * (dLat / 2).abs() +
        dLng.abs() * dLng.abs(); // fast approximation
    return earthRadius * a;
  }

  static double _toRadians(double deg) => deg * (3.141592653589793 / 180.0);
}
