import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/app_constants.dart';

/// Live driver location shared between the Driver, Customer and Admin apps.
///
/// The driver app calls [publish] whenever its GPS position changes.
/// Customer / admin screens listen with [watch] and move the driver marker.
/// Uses the Supabase `driver_locations` table (see supabase_tracking.sql).
/// When Supabase is not configured it falls back to an in-memory channel
/// (works within a single running app instance only).
class TrackingService {
  static const String _table = 'driver_locations';

  static bool get _isSupabaseConfigured =>
      AppConstants.supabaseUrl != 'YOUR_SUPABASE_PROJECT_URL' &&
      AppConstants.supabaseAnonKey != 'YOUR_SUPABASE_PROJECT_ANON_KEY';

  // In-memory fallback
  static final Map<String, StreamController<DriverLocation>> _local = {};
  static final Map<String, DriverLocation> _lastLocal = {};

  static String _key(String orderId) => orderId.replaceAll('#', '');

  /// Driver side: send the current position for [orderId].
  static Future<void> publish({
    required String orderId,
    required String driverId,
    required double lat,
    required double lng,
  }) async {
    final key = _key(orderId);
    final loc = DriverLocation(LatLng(lat, lng), DateTime.now());
    _lastLocal[key] = loc;
    _local.putIfAbsent(key, () => StreamController.broadcast()).add(loc);

    if (!_isSupabaseConfigured) return;
    try {
      await Supabase.instance.client.from(_table).upsert({
        'order_id': key,
        'driver_id': driverId,
        'lat': lat,
        'lng': lng,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Tracking publish failed: $e');
    }
  }

  /// Customer / admin side: live stream of the driver's location.
  static Stream<DriverLocation> watch(String orderId) {
    final key = _key(orderId);

    if (_isSupabaseConfigured) {
      try {
        return Supabase.instance.client
            .from(_table)
            .stream(primaryKey: ['order_id'])
            .eq('order_id', key)
            .where((rows) => rows.isNotEmpty)
            .map((rows) {
              final r = rows.first;
              return DriverLocation(
                LatLng(
                  (r['lat'] as num).toDouble(),
                  (r['lng'] as num).toDouble(),
                ),
                DateTime.tryParse(r['updated_at']?.toString() ?? '')
                        ?.toLocal() ??
                    DateTime.now(),
              );
            });
      } catch (e) {
        debugPrint('Tracking stream failed, using local channel: $e');
      }
    }

    final controller = _local.putIfAbsent(
      key,
      () => StreamController<DriverLocation>.broadcast(),
    );
    final last = _lastLocal[key];
    return last == null
        ? controller.stream
        : (() async* {
            yield last;
            yield* controller.stream;
          })();
  }

  // ---------- Geocoding (address -> coordinates) ----------
  static final Map<String, LatLng?> _geoCache = {};

  /// Converts a Philippine address into coordinates using OpenStreetMap
  /// Nominatim. Progressively drops the most specific part (house/street,
  /// barangay) until something is found.
  static Future<LatLng?> geocode(String address) async {
    if (_geoCache.containsKey(address)) return _geoCache[address];

    final parts = address
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    for (var i = 0; i < parts.length && parts.length - i >= 2; i++) {
      final query = parts
          .sublist(i)
          .map((p) => p.replaceFirst(RegExp(r'^Brgy\.?\s*', caseSensitive: false), ''))
          .join(', ');
      try {
        final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
          'q': '$query, Philippines',
          'format': 'json',
          'limit': '1',
          'countrycodes': 'ph',
        });
        final res = await http.get(uri).timeout(const Duration(seconds: 10));
        if (res.statusCode == 200) {
          final list = jsonDecode(res.body) as List<dynamic>;
          if (list.isNotEmpty) {
            final p = LatLng(
              double.parse(list.first['lat'] as String),
              double.parse(list.first['lon'] as String),
            );
            _geoCache[address] = p;
            return p;
          }
        }
      } catch (e) {
        debugPrint('Geocode failed for "$query": $e');
      }
      // Respect Nominatim usage policy (max ~1 request/second)
      await Future.delayed(const Duration(milliseconds: 1100));
    }
    _geoCache[address] = null;
    return null;
  }
}

class DriverLocation {
  final LatLng position;
  final DateTime updatedAt;
  const DriverLocation(this.position, this.updatedAt);
}
