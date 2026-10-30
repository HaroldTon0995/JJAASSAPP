import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme/app_theme.dart';

class NavigationLauncher {
  /// Launches turn-by-turn navigation in the driver's native Google Maps app
  /// using the exact GPS coordinates pinned by the customer.
  static Future<bool> openGoogleMapsNavigation({
    required double lat,
    required double lng,
    String? address,
  }) async {
    // 1. First attempt: Native Android Google Navigation intent (starts turn-by-turn directly)
    final nativeUri = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
    try {
      if (await canLaunchUrl(nativeUri)) {
        return await launchUrl(nativeUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}

    // 2. Second attempt: Google Maps Directions universal web/app URL
    final universalUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
    );
    try {
      if (await canLaunchUrl(universalUri)) {
        return await launchUrl(universalUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}

    // 3. Fallback: Search by address or coordinates in web browser
    final fallbackUri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    return await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
  }

  /// Launches Waze navigation directly to the customer's pinned location.
  static Future<bool> openWazeNavigation({
    required double lat,
    required double lng,
  }) async {
    final nativeUri = Uri.parse('waze://?ll=$lat,$lng&navigate=yes');
    try {
      if (await canLaunchUrl(nativeUri)) {
        return await launchUrl(nativeUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}

    final webUri = Uri.parse('https://waze.com/ul?ll=$lat,$lng&navigate=yes');
    return await launchUrl(webUri, mode: LaunchMode.externalApplication);
  }

  /// Calls the customer's phone number.
  static Future<bool> callPhone(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri);
    }
    return false;
  }

  /// Presents a Grab/Foodpanda-style bottom sheet for drivers with quick-action buttons:
  /// - Google Maps Turn-by-Turn
  /// - Waze Navigation
  /// - Call Customer
  static void showNavigationSheet(
    BuildContext context, {
    required double lat,
    required double lng,
    required String customerName,
    required String address,
    String? phone,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.navigation_rounded,
                      color: AppTheme.primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Driver Navigation',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.navyColor,
                          ),
                        ),
                        Text(
                          'Customer: $customerName',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.pin_drop_rounded,
                          size: 16,
                          color: Color(0xFFE11D48),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            address,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Exact GPS Pin: ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF0284C7),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              // Option 1: Google Maps
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    openGoogleMapsNavigation(lat: lat, lng: lng, address: address);
                  },
                  icon: const Icon(Icons.map_rounded, color: Colors.white, size: 20),
                  label: const Text(
                    'Navigate with Google Maps (Voice Directions)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D63B8),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Option 2: Waze
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    openWazeNavigation(lat: lat, lng: lng);
                  },
                  icon: const Icon(Icons.alt_route_rounded, color: Color(0xFF0F172A), size: 20),
                  label: const Text(
                    'Navigate with Waze',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              if (phone != null && phone.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      callPhone(phone);
                    },
                    icon: const Icon(Icons.phone_rounded, color: Color(0xFF10B981), size: 20),
                    label: Text(
                      'Call Customer ($phone)',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Color(0xFF10B981), width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
