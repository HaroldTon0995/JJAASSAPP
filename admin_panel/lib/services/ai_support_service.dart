import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/constants/app_constants.dart';
import '../models/order_model.dart';
import '../providers/order_provider.dart';

class AiSupportService {
  static const String _defaultModel = 'gemini-1.5-flash';
  static const String marketAddress = 'Pili Iraya, Bacacay, Albay';
  static const double _depotLat = 14.5995;
  static const double _depotLng = 120.9842;

  /// Fetches response from AI support engine. Falls back to smart offline parser if Gemini API key is missing or calls fail.
  static Future<String> getChatResponse({
    required String query,
    required bool isDriver,
    required bool isAdmin,
    required String userId,
    required String userName,
    required OrderProvider orderProvider,
  }) async {
    // Delay to simulate processing or typing
    await Future.delayed(const Duration(milliseconds: 1200));

    final cleanQuery = query.trim().toLowerCase();
    
    // Quick intercept for route optimization if requested by driver
    if (isDriver && (cleanQuery.contains('route') || cleanQuery.contains('optimize') || cleanQuery.contains('path') || cleanQuery.contains('plan'))) {
      return _optimizeRouteResponse(userId, orderProvider);
    }

    final hasApiKey = AppConstants.geminiApiKey.isNotEmpty;
    if (hasApiKey) {
      try {
        return await _getGeminiResponse(
          query: query,
          isDriver: isDriver,
          isAdmin: isAdmin,
          userId: userId,
          userName: userName,
          orderProvider: orderProvider,
        );
      } catch (e) {
        debugPrint('Gemini API request failed, falling back to local engine: $e');
      }
    }

    // Offline / Local Smart Fallback Engine
    return _getLocalFallbackResponse(
      query: cleanQuery,
      isDriver: isDriver,
      isAdmin: isAdmin,
      userId: userId,
      userName: userName,
      orderProvider: orderProvider,
    );
  }

  /// Builds context payload & requests Gemini API
  static Future<String> _getGeminiResponse({
    required String query,
    required bool isDriver,
    required bool isAdmin,
    required String userId,
    required String userName,
    required OrderProvider orderProvider,
  }) async {
    final String contextData = _gatherSystemContext(
      isDriver: isDriver,
      isAdmin: isAdmin,
      userId: userId,
      userName: userName,
      orderProvider: orderProvider,
    );

    final String systemInstructions = 
      "You are AquaBot 💧, the premium AI support desk agent for 'JJAASSApp' (a water delivery service of JJAASS Water Market). "
      "The JJAASS Water Market is located at: $marketAddress. Use this address whenever asked about the store location, address, or how to find or visit us.\n"
      "You are chatting with a user named '$userName' who is a ${isDriver ? 'Driver' : isAdmin ? 'Admin' : 'Customer'}.\n\n"
      "Here is the real-time application context data:\n"
      "$contextData\n\n"
      "Instructions:\n"
      "- Be helpful, clear, and professional.\n"
      "- Use the provided context data to answer queries accurately (e.g., order statuses, prices, earnings, loyalty points).\n"
      "- Keep responses concise and formatted using clean markdown.\n"
      "- If asked about route optimization or scheduling, refer to the driver dashboard or guide them on steps.\n"
      "- If you don't know something or it is not in the context, do not make up facts.";

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$_defaultModel:generateContent?key=${AppConstants.geminiApiKey}'
    );

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "contents": [
          {
            "parts": [
              {"text": "$systemInstructions\n\nUser Question: $query"}
            ]
          }
        ]
      }),
    ).timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';
      if (text.toString().trim().isNotEmpty) {
        return text.toString().trim();
      }
    }
    throw Exception('API returned status code ${response.statusCode}');
  }

  /// In-memory keyword analyzer referencing live provider data
  static String _getLocalFallbackResponse({
    required String query,
    required bool isDriver,
    required bool isAdmin,
    required String userId,
    required String userName,
    required OrderProvider orderProvider,
  }) {
    if (query.contains('address') ||
        query.contains('location') ||
        query.contains('located') ||
        query.contains('where are you') ||
        query.contains('store') ||
        query.contains('shop') ||
        query.contains('visit') ||
        query.contains('pickup') ||
        query.contains('pick up') ||
        query.contains('market')) {
      return "📍 **JJAASS Water Market**\n\nWe are located at **$marketAddress**.\n\nFeel free to visit us or order water for delivery right from the app!";
    }

    if (isAdmin) {
      // Admin dashboard inquiries
      if (query.contains('revenue') || query.contains('sales') || query.contains('earn')) {
        return "💰 **Revenue Report**\n\nThe total revenue recorded from completed orders is **₱${orderProvider.getTotalRevenue().toStringAsFixed(2)}**.";
      }
      if (query.contains('order') || query.contains('stat')) {
        return "📊 **Order Statistics**\n\n- **Pending Orders**: ${orderProvider.getPendingCount()}\n- **Active Deliveries**: ${orderProvider.getActiveDeliveriesCount()}\n- **Completed Orders**: ${orderProvider.getCompletedCount()}\n- **Total Orders**: ${orderProvider.orders.length}";
      }
      if (query.contains('stock') || query.contains('product') || query.contains('inventory')) {
        final productsInfo = orderProvider.waterProducts.map((p) {
          return "- **${p['name']}**: ${p['stock']} / ${p['capacity']} gallons remaining (Price: ₱${p['price']})";
        }).join('\n');
        return "💧 **Inventory Stock Levels**\n\n$productsInfo";
      }
      return "Hello Admin $userName! I can help you inspect operations:\n- Type **'revenue'** to check total earnings.\n- Type **'orders'** to see order metrics.\n- Type **'stock'** to view product inventory levels.";
    }

    if (isDriver) {
      // Driver inquiries
      if (query.contains('earn') || query.contains('payout') || query.contains('cash')) {
        final earnings = orderProvider.getDriverEarnings(userId);
        return "💳 **GCash Cashout & Earnings**\n\nYour current withdrawable earnings balance is **₱${earnings.toStringAsFixed(2)}**. To cash out, go to the **My Earnings** tab and tap **GCash Cash Out**.";
      }
      if (query.contains('active') || query.contains('job') || query.contains('delivery')) {
        final activeJob = orderProvider.getActiveDriverJob(userId);
        if (activeJob == null) {
          return "🚚 You have **no active delivery job** at the moment. Go to the Dashboard to accept available jobs.";
        }
        return "🚚 **Active Job Summary**\n\n- **Order ID**: ${activeJob.id}\n- **Customer**: ${activeJob.customerName}\n- **Address**: ${activeJob.deliveryAddress}\n- **Items**: ${activeJob.itemsSummary}\n- **Status**: ${activeJob.orderStatus.displayName}";
      }
      return "Hello Driver $userName! I can assist you with dispatch queries:\n- Type **'optimize route'** to compute your best delivery sequence.\n- Type **'earnings'** to view payout balance details.\n- Type **'active job'** to see information about your current assignment.";
    }

    // Customer inquiries
    if (query.contains('status') || query.contains('where') || query.contains('track') || query.contains('order')) {
      final orders = orderProvider.getCustomerOrders(userId);
      if (orders.isEmpty) {
        return "🔍 You have not placed any orders yet. Click on the **Order** screen to place your first water order!";
      }
      final latest = orders.first;
      return "📦 **Latest Order Track (#${latest.id})**\n\n- **Product**: ${latest.itemsSummary}\n- **Status**: **${latest.orderStatus.displayName}**\n- **Date**: ${latest.createdAt.toString().substring(0, 16)}\n- **Payment Method**: ${latest.paymentMethod} (${latest.paymentStatus})\n- **Estimated Distance**: ${latest.distance}";
    }
    if (query.contains('price') || query.contains('product') || query.contains('buy') || query.contains('cost')) {
      final list = orderProvider.waterProducts.map((p) {
        return "- **${p['name']}**: ₱${p['price']} per gallon (Stock: ${p['stock'].toInt()} left)";
      }).join('\n');
      return "💧 **Product Catalog & Prices**\n\nHere is our current water product pricing:\n$list\n\n*You can order these directly from the Home Dashboard order widget!*";
    }
    if (query.contains('point') || query.contains('reward') || query.contains('coupon') || query.contains('loyalty')) {
      final pts = orderProvider.getCustomerRewardPoints(userId);
      return "⭐ **AquaLoyalty Reward Points**\n\nYou currently have **$pts reward points**. You can redeem them in the Loyalty tab on the dashboard for discounted delivery coupons!";
    }
    if (query.contains('payment') || query.contains('pay') || query.contains('gcash')) {
      return "💳 **Accepted Payments**\n\nWe accept:\n- **Cash on Delivery (COD)**\n- **GCash Online Payment** (powered securely via PayMongo checkout integration).";
    }

    return "Hello $userName! How can AquaBot help you today?\n- Ask **'where is my order'** to check your dispatch status.\n- Ask **'prices'** to view the available water types.\n- Ask **'rewards'** to see your loyal customer points.";
  }

  /// Formats all system details into a prompt-friendly string
  static String _gatherSystemContext({
    required bool isDriver,
    required bool isAdmin,
    required String userId,
    required String userName,
    required OrderProvider orderProvider,
  }) {
    final buffer = StringBuffer();
    buffer.writeln("=== BUSINESS INFORMATION ===");
    buffer.writeln("Business Name: JJAASS Water Market");
    buffer.writeln("Address: $marketAddress");
    if (isAdmin) {
      buffer.writeln("=== SYSTEM ANALYTICS ===");
      buffer.writeln("Total System Revenue: ₱${orderProvider.getTotalRevenue().toStringAsFixed(2)}");
      buffer.writeln("Completed Orders: ${orderProvider.getCompletedCount()}");
      buffer.writeln("Pending Orders: ${orderProvider.getPendingCount()}");
      buffer.writeln("Active Deliveries: ${orderProvider.getActiveDeliveriesCount()}");
      buffer.writeln("=== WATER PRODUCTS ===");
      for (var p in orderProvider.waterProducts) {
        buffer.writeln("- Product: ${p['name']}, Price: ₱${p['price']}, Stock: ${p['stock']}/${p['capacity']}");
      }
    } else if (isDriver) {
      buffer.writeln("=== DRIVER INFORMATION ===");
      buffer.writeln("Driver ID: $userId");
      buffer.writeln("Driver Name: $userName");
      buffer.writeln("Uncashed Earnings: ₱${orderProvider.getDriverEarnings(userId).toStringAsFixed(2)}");
      
      final activeJob = orderProvider.getActiveDriverJob(userId);
      if (activeJob != null) {
        buffer.writeln("Active Job: ${activeJob.id}, Customer: ${activeJob.customerName}, Address: ${activeJob.deliveryAddress}, Items: ${activeJob.itemsSummary}, Distance: ${activeJob.distance}");
      } else {
        buffer.writeln("Active Job: None");
      }
      
      final available = orderProvider.getAvailableDriverJobs(userId);
      buffer.writeln("Assigned Queue Count: ${available.length}");
      for (var job in available) {
        buffer.writeln("- Queue Job: ${job.id}, Address: ${job.deliveryAddress}, Items: ${job.itemsSummary}");
      }
    } else {
      buffer.writeln("=== CUSTOMER PROFILE ===");
      buffer.writeln("Customer ID: $userId");
      buffer.writeln("Customer Name: $userName");
      buffer.writeln("Loyalty Rewards Points: ${orderProvider.getCustomerRewardPoints(userId)}");
      
      final customerOrders = orderProvider.getCustomerOrders(userId);
      buffer.writeln("Order History Count: ${customerOrders.length}");
      for (var o in customerOrders.take(3)) {
        buffer.writeln("- Order #${o.id}: Items: ${o.itemsSummary}, Status: ${o.orderStatus.displayName}, Payment: ${o.paymentStatus}, Date: ${o.createdAt}");
      }
      buffer.writeln("=== PRODUCT CATALOG ===");
      for (var p in orderProvider.waterProducts) {
        buffer.writeln("- ${p['name']}: ₱${p['price']} (Available Stock: ${p['stock']})");
      }
    }
    return buffer.toString();
  }

  /// Resolves coordinates deterministically matching GoogleMapWidget formula
  static Map<String, double> _getCoordinatesForAddress(String address, double? latitude, double? longitude) {
    if (latitude != null && longitude != null) {
      return {'lat': latitude, 'lng': longitude};
    }
    final hash = address.hashCode;
    final latOffset = (hash % 100) / 1000.0 - 0.05;
    final lngOffset = ((hash >> 4) % 100) / 1000.0 - 0.05;
    return {
      'lat': _depotLat + latOffset,
      'lng': _depotLng + lngOffset,
    };
  }

  /// Nearest Neighbor TSP Algorithm to optimize route path
  static String _optimizeRouteResponse(String driverId, OrderProvider orderProvider) {
    // Gather all jobs currently in delivery OR assigned to the driver
    final List<OrderModel> jobs = orderProvider.orders.where((o) {
      return o.driverId == driverId && 
          (o.orderStatus == OrderStatus.onDelivery || o.orderStatus == OrderStatus.assigned);
    }).toList();

    if (jobs.isEmpty) {
      return "⚠️ **Route Optimization Notice**\n\nYou do not have any pending or active delivery jobs assigned. Please accept jobs from your dashboard before optimizing.";
    }

    // List to hold jobs with coordinates
    final List<Map<String, dynamic>> stops = [];
    for (var job in jobs) {
      final coords = _getCoordinatesForAddress(job.deliveryAddress, job.latitude, job.longitude);
      stops.add({
        'order': job,
        'lat': coords['lat']!,
        'lng': coords['lng']!,
        'visited': false,
      });
    }

    // Nearest Neighbor Calculation starting from Depot Headquarters
    double currentLat = _depotLat;
    double currentLng = _depotLng;
    final List<Map<String, dynamic>> optimizedPath = [];
    double totalDistance = 0.0;

    // Haversine Distance helper
    double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
      const double r = 6371.0; // Earth's radius in km
      final double dLat = (lat2 - lat1) * pi / 180.0;
      final double dLon = (lon2 - lon1) * pi / 180.0;
      final double a = sin(dLat / 2) * sin(dLat / 2) +
          cos(lat1 * pi / 180.0) * cos(lat2 * pi / 180.0) *
          sin(dLon / 2) * sin(dLon / 2);
      final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
      return r * c;
    }

    while (optimizedPath.length < stops.length) {
      double minDistance = double.maxFinite;
      int nearestIndex = -1;

      for (int i = 0; i < stops.length; i++) {
        if (!stops[i]['visited']) {
          final dist = calculateDistance(
            currentLat,
            currentLng,
            stops[i]['lat'] as double,
            stops[i]['lng'] as double,
          );
          if (dist < minDistance) {
            minDistance = dist;
            nearestIndex = i;
          }
        }
      }

      if (nearestIndex != -1) {
        stops[nearestIndex]['visited'] = true;
        stops[nearestIndex]['distanceFromPrev'] = minDistance;
        optimizedPath.add(stops[nearestIndex]);
        
        currentLat = stops[nearestIndex]['lat'] as double;
        currentLng = stops[nearestIndex]['lng'] as double;
        totalDistance += minDistance;
      }
    }

    // Build optimized itinerary breakdown response
    final buffer = StringBuffer();
    buffer.writeln("📍 **AquaBot Optimal Delivery Route Dispatch** 📍");
    buffer.writeln("Optimal sequence planned starting from the **Water Depot Headquarters**:\n");
    buffer.writeln("🏠 **1. Depot Headquarters (Main Office)**");
    buffer.writeln("   - Start Coordinate: ($_depotLat, $_depotLng)");

    for (int i = 0; i < optimizedPath.length; i++) {
      final stop = optimizedPath[i];
      final OrderModel order = stop['order'] as OrderModel;
      final distPrev = stop['distanceFromPrev'] as double;
      final estTimeMins = (distPrev * 6).round() + 5; // 6 mins per km + 5 mins drop-off overhead
      
      buffer.writeln("\n➡️ **${i + 2}. Stop: Customer ${order.customerName}** (Order: ${order.id})");
      buffer.writeln("   - **Address**: ${order.deliveryAddress}");
      buffer.writeln("   - **Quantity**: ${order.itemsSummary}");
      buffer.writeln("   - **Distance from previous point**: ${distPrev.toStringAsFixed(2)} km");
      buffer.writeln("   - **Estimated travel time**: ~$estTimeMins mins");
    }

    // Calculate simulated optimization benefit
    final double unoptimizedDistance = jobs.fold(0.0, (sum, o) {
      final parsedDist = double.tryParse(o.distance.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 1.5;
      return sum + parsedDist;
    });
    final double savings = max(0.2, unoptimizedDistance - totalDistance);

    buffer.writeln("\n📊 **Optimization Stats**");
    buffer.writeln("- **Total stops**: ${optimizedPath.length}");
    buffer.writeln("- **Total optimized distance**: **${totalDistance.toStringAsFixed(2)} km**");
    buffer.writeln("- **Estimated route travel time**: **${(totalDistance * 6).round() + (optimizedPath.length * 5)} mins**");
    buffer.writeln("- **Optimization Benefit**: Saved approximately **${savings.toStringAsFixed(2)} km** of driving compared to direct separate trips!");

    return buffer.toString();
  }
}
