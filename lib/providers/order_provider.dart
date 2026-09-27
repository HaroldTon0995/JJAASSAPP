import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/app_constants.dart';
import '../models/order_model.dart';
import '../services/location_service.dart';

class OrderProvider extends ChangeNotifier {
  final List<OrderModel> _orders = [];
  final Map<String, double> _driverCashedOutEarnings = {};
  bool _isLoading = false;
  Timer? _pollingTimer;

  // Shared dynamic water products catalog
  final List<Map<String, dynamic>> _waterProducts = [
    {
      'id': 'prod_purified',
      'name': '19L Purified Water',
      'price': 50.0,
      'stock': 127.0,
      'capacity': 150.0,
      'color': Colors.blue,
      'icon': Icons.water_drop_rounded,
    },
    {
      'id': 'prod_alkaline',
      'name': '19L Alkaline Water',
      'price': 60.0,
      'stock': 70.0,
      'capacity': 100.0,
      'color': Colors.cyan,
      'icon': Icons.opacity_rounded,
    },
  ];

  List<Map<String, dynamic>> get waterProducts => _waterProducts;

  void addWaterProduct({
    required String name,
    required double price,
    required double stock,
    required double capacity,
    required Color color,
    required IconData icon,
  }) {
    _waterProducts.add({
      'id': 'prod_${DateTime.now().millisecondsSinceEpoch}',
      'name': name,
      'price': price,
      'stock': stock,
      'capacity': capacity,
      'color': color,
      'icon': icon,
    });
    notifyListeners();
  }

  void refillWaterProduct(String id, double amount) {
    final idx = _waterProducts.indexWhere((p) => p['id'] == id);
    if (idx != -1) {
      final capacity = _waterProducts[idx]['capacity'] as double;
      final currentStock = _waterProducts[idx]['stock'] as double;
      _waterProducts[idx]['stock'] = min(capacity, currentStock + amount);
      notifyListeners();
    }
  }

  void deductProductStock(String name, int qty) {
    final idx = _waterProducts.indexWhere((p) => p['name'] == name);
    if (idx != -1) {
      final currentStock = _waterProducts[idx]['stock'] as double;
      _waterProducts[idx]['stock'] = max(0.0, currentStock - qty);
      notifyListeners();
    }
  }

  bool get isLoading => _isLoading;
  List<OrderModel> get orders => List.unmodifiable(_orders);

  bool get _isSupabaseConfigured =>
      AppConstants.supabaseUrl != 'YOUR_SUPABASE_PROJECT_URL' &&
      AppConstants.supabaseAnonKey != 'YOUR_SUPABASE_PROJECT_ANON_KEY';

  StreamSubscription? _ordersSubscription;

  OrderProvider() {
    if (_isSupabaseConfigured) {
      // 1. Initial direct fetch
      fetchSupabaseOrders();
      // 2. Realtime Stream
      _listenToSupabaseOrders();
      // 3. Fallback sync polling every 3 seconds for guaranteed cross-device sync
      _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        fetchSupabaseOrders(silent: true);
      });
    } else {
      _seedMockOrders();
    }
  }

  Future<void> fetchSupabaseOrders({bool silent = false}) async {
    if (!_isSupabaseConfigured) return;
    try {
      final client = Supabase.instance.client;
      final List<dynamic> response = await client.from('orders').select();
      
      final fetched = response
          .map((item) => OrderModel.fromJson(item as Map<String, dynamic>))
          .toList();

      // Sort newest first
      fetched.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (fetched.isNotEmpty || _orders.isEmpty) {
        _orders.clear();
        _orders.addAll(fetched);
        if (!silent) notifyListeners();
      }
    } catch (e) {
      debugPrint('Supabase direct fetch orders error: $e');
    }
  }

  void _listenToSupabaseOrders() {
    if (!_isSupabaseConfigured) return;
    try {
      final client = Supabase.instance.client;
      _ordersSubscription = client
          .from('orders')
          .stream(primaryKey: ['id'])
          .listen(
            (List<Map<String, dynamic>> response) {
              final fetched = response
                  .map((item) => OrderModel.fromJson(item))
                  .toList();
              
              // Sort newest first
              fetched.sort((a, b) => b.createdAt.compareTo(a.createdAt));

              _orders.clear();
              _orders.addAll(fetched);
              notifyListeners();
            },
            onError: (error) {
              debugPrint('Supabase Realtime Orders stream error: $error');
            },
          );
    } catch (e) {
      debugPrint('Supabase Realtime Orders stream setup failed: $e');
    }
  }

  @override
  void dispose() {
    _ordersSubscription?.cancel();
    _pollingTimer?.cancel();
    super.dispose();
  }

  // Customer Actions

  Future<OrderModel> placeOrder({
    required String customerId,
    required String customerName,
    required String customerPhone,
    required String deliveryAddress,
    required String waterType,
    required int quantity,
    required double pricePerUnit,
    required String paymentMethod,
    String? paymentStatus,
  }) async {
    _isLoading = true;
    notifyListeners();

    final randomNum = 1000 + Random().nextInt(8999);
    final orderId = '#ORD-00$randomNum';
    final txnId = '#TXN-88$randomNum';
    final totalAmount = pricePerUnit * quantity;

    final newOrder = OrderModel(
      id: orderId,
      txnId: txnId,
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      deliveryAddress: deliveryAddress,
      waterType: waterType,
      quantity: quantity,
      pricePerUnit: pricePerUnit,
      totalAmount: totalAmount,
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus ?? 'Pending',
      orderStatus: OrderStatus.pending,
      createdAt: DateTime.now(),
      distance: '${(1.0 + Random().nextDouble() * 3.0).toStringAsFixed(1)} km',
    );

    _orders.insert(0, newOrder);
    deductProductStock(waterType, quantity);

    if (_isSupabaseConfigured) {
      try {
        final client = Supabase.instance.client;
        
        // Use clean JSON with camelCase and standard columns
        final insertMap = {
          'id': newOrder.id,
          'txnId': newOrder.txnId,
          'customerId': newOrder.customerId,
          'customerName': newOrder.customerName,
          'customerPhone': newOrder.customerPhone,
          'deliveryAddress': newOrder.deliveryAddress,
          'waterType': newOrder.waterType,
          'quantity': newOrder.quantity,
          'pricePerUnit': newOrder.pricePerUnit,
          'totalAmount': newOrder.totalAmount,
          'paymentMethod': newOrder.paymentMethod,
          'paymentStatus': newOrder.paymentStatus,
          'orderStatus': newOrder.orderStatus.name,
          'createdAt': newOrder.createdAt.toIso8601String(),
          'distance': newOrder.distance,
        };

        await client.from('orders').insert(insertMap);
        debugPrint('Successfully inserted order ${newOrder.id} to Supabase!');
        
        // Refresh immediately
        await fetchSupabaseOrders(silent: true);
      } catch (e) {
        debugPrint('Supabase insert failed: $e');
      }
    }

    _isLoading = false;
    notifyListeners();
    return newOrder;
  }

  // Driver Actions

  Future<bool> acceptJob({
    required String orderId,
    required String driverId,
    required String driverName,
  }) async {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index == -1) return false;

    // Check if driver already has an active job
    final hasActive = _orders.any(
      (o) => o.driverId == driverId && o.orderStatus == OrderStatus.onDelivery,
    );
    if (hasActive) return false;

    _orders[index].driverId = driverId;
    _orders[index].driverName = driverName;
    _orders[index].orderStatus = OrderStatus.onDelivery;

    // Start live GPS broadcasting for driver
    LocationService().startBroadcasting(
      driverId: driverId,
      driverName: driverName,
      orderId: orderId,
    );

    if (_isSupabaseConfigured) {
      try {
        final client = Supabase.instance.client;
        await client
            .from('orders')
            .update({
              'driverId': driverId,
              'driverName': driverName,
              'orderStatus': OrderStatus.onDelivery.name,
            })
            .eq('id', orderId);
        await fetchSupabaseOrders(silent: true);
      } catch (e) {
        debugPrint('Supabase accept order update error: $e');
      }
    }

    notifyListeners();
    return true;
  }

  Future<bool> completeJob({
    required String orderId,
    required String driverId,
  }) async {
    final index = _orders.indexWhere(
      (o) => o.id == orderId && o.driverId == driverId,
    );
    if (index == -1) return false;

    _orders[index].orderStatus = OrderStatus.completed;
    _orders[index].paymentStatus = 'Paid';
    _orders[index].completedAt = DateTime.now();

    // Stop GPS broadcasting
    LocationService().stopBroadcasting();

    if (_isSupabaseConfigured) {
      try {
        final client = Supabase.instance.client;
        await client
            .from('orders')
            .update({
              'orderStatus': OrderStatus.completed.name,
              'paymentStatus': 'Paid',
              'completedAt': DateTime.now().toIso8601String(),
            })
            .eq('id', orderId);
        await fetchSupabaseOrders(silent: true);
      } catch (e) {
        debugPrint('Supabase complete order update error: $e');
      }
    }

    notifyListeners();
    return true;
  }

  void cashOutDriverEarnings(String driverId) {
    final currentEarnings = getDriverEarnings(driverId);
    if (currentEarnings <= 0) return;

    _driverCashedOutEarnings[driverId] =
        (_driverCashedOutEarnings[driverId] ?? 0.0) + currentEarnings;

    notifyListeners();
  }

  // Admin Actions

  Future<void> confirmOrder(String orderId) async {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index == -1) return;

    _orders[index].orderStatus = OrderStatus.confirmed;

    if (_isSupabaseConfigured) {
      try {
        final client = Supabase.instance.client;
        await client
            .from('orders')
            .update({'orderStatus': OrderStatus.confirmed.name})
            .eq('id', orderId);
        await fetchSupabaseOrders(silent: true);
      } catch (e) {
        debugPrint('Supabase confirm order update error: $e');
      }
    }

    notifyListeners();
  }

  Future<void> markOrderAsPaid(String orderId) async {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index == -1) return;

    _orders[index].paymentStatus = 'Paid';

    if (_isSupabaseConfigured) {
      try {
        final client = Supabase.instance.client;
        await client
            .from('orders')
            .update({'paymentStatus': 'Paid'})
            .eq('id', orderId);
        await fetchSupabaseOrders(silent: true);
      } catch (e) {
        debugPrint('Supabase mark order paid error: $e');
      }
    }

    notifyListeners();
  }

  Future<void> assignDriver({
    required String orderId,
    required String driverId,
    required String driverName,
  }) async {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index == -1) return;

    _orders[index].driverId = driverId;
    _orders[index].driverName = driverName;
    _orders[index].orderStatus = OrderStatus.assigned;

    if (_isSupabaseConfigured) {
      try {
        final client = Supabase.instance.client;
        await client
            .from('orders')
            .update({
              'driverId': driverId,
              'driverName': driverName,
              'orderStatus': OrderStatus.assigned.name,
            })
            .eq('id', orderId);
        await fetchSupabaseOrders(silent: true);
      } catch (e) {
        debugPrint('Supabase assign driver update error: $e');
      }
    }

    notifyListeners();
  }

  Future<void> updateOrderStatus({
    required String orderId,
    required OrderStatus newStatus,
    String? driverId,
    String? driverName,
  }) async {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index == -1) return;

    _orders[index].orderStatus = newStatus;
    if (newStatus == OrderStatus.completed) {
      _orders[index].paymentStatus = 'Paid';
      _orders[index].completedAt = DateTime.now();
      LocationService().stopBroadcasting();
    }
    if (driverId != null) {
      _orders[index].driverId = driverId;
    }
    if (driverName != null) {
      _orders[index].driverName = driverName;
    }

    if (_isSupabaseConfigured) {
      try {
        final client = Supabase.instance.client;
        final updateData = <String, dynamic>{'orderStatus': newStatus.name};
        if (newStatus == OrderStatus.completed) {
          updateData['paymentStatus'] = 'Paid';
          updateData['completedAt'] = DateTime.now().toIso8601String();
        }
        if (driverId != null) updateData['driverId'] = driverId;
        if (driverName != null) updateData['driverName'] = driverName;

        await client.from('orders').update(updateData).eq('id', orderId);
        await fetchSupabaseOrders(silent: true);
      } catch (e) {
        debugPrint('Supabase admin update order error: $e');
      }
    }

    notifyListeners();
  }

  // Helper Queries

  // Customer Queries
  List<OrderModel> getCustomerOrders(String customerId) {
    if (customerId.isEmpty) return [];
    return _orders.where((o) => o.customerId == customerId).toList();
  }

  List<OrderModel> getCustomerDeliveries(String customerId) {
    if (customerId.isEmpty) return [];
    return _orders.where((o) => o.customerId == customerId).toList();
  }

  int getCustomerRewardPoints(String customerId) {
    if (customerId.isEmpty) return 0;
    final completed = getCustomerOrders(
      customerId,
    ).where((o) => o.orderStatus == OrderStatus.completed);
    int points = 100;
    for (var o in completed) {
      points += o.quantity * 10;
    }
    return points;
  }

  // Driver Queries
  List<OrderModel> getAvailableDriverJobs(String driverId) {
    if (driverId.isEmpty) return [];
    return _orders
        .where(
          (o) =>
              (o.orderStatus == OrderStatus.assigned || o.orderStatus == OrderStatus.confirmed) &&
              (o.driverId == driverId || o.driverId == null || o.driverId!.isEmpty),
        )
        .toList();
  }

  OrderModel? getActiveDriverJob(String driverId) {
    if (driverId.isEmpty) return null;
    final list = _orders.where(
      (o) => o.driverId == driverId && o.orderStatus == OrderStatus.onDelivery,
    );
    return list.isNotEmpty ? list.first : null;
  }

  List<OrderModel> getDriverCompletedJobs(String driverId) {
    if (driverId.isEmpty) return [];
    return _orders
        .where(
          (o) =>
              o.driverId == driverId && o.orderStatus == OrderStatus.completed,
        )
        .toList();
  }

  double getDriverEarnings(String driverId) {
    final completed = getDriverCompletedJobs(driverId);
    double gross = 0.0;
    for (var job in completed) {
      gross += job.totalAmount * 0.5;
    }
    final cashedOut = _driverCashedOutEarnings[driverId] ?? 0.0;
    return max(0.0, gross - cashedOut);
  }

  // Admin Analytics Queries
  double getTotalRevenue() {
    double total = 0.0;
    for (var order in _orders) {
      if (order.orderStatus == OrderStatus.completed ||
          order.paymentStatus == 'Paid') {
        total += order.totalAmount;
      }
    }
    return total;
  }

  int getCompletedCount() {
    return _orders.where((o) => o.orderStatus == OrderStatus.completed).length;
  }

  int getPendingCount() {
    return _orders.where((o) => o.orderStatus == OrderStatus.pending).length;
  }

  int getActiveDeliveriesCount() {
    return _orders.where((o) => o.orderStatus == OrderStatus.onDelivery).length;
  }

  void _seedMockOrders() {
    // Fallback seed when Supabase is not configured
  }
}
