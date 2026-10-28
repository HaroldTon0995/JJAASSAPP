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

  // Shared dynamic inventory items catalog (Water Refills, Containers & Bottles, Accessories)
  final List<Map<String, dynamic>> _inventoryItems = [
    {
      'id': 'prod_purified',
      'name': '19L Purified Water',
      'category': 'water',
      'unit': 'Gallons',
      'price': 50.0,
      'stock': 127.0,
      'capacity': 150.0,
      'color': Colors.blue,
      'icon': Icons.water_drop_rounded,
      'description': 'Multi-stage filtered pure drinking water refill',
    },
    {
      'id': 'prod_alkaline',
      'name': '19L Alkaline Water',
      'category': 'water',
      'unit': 'Gallons',
      'price': 60.0,
      'stock': 70.0,
      'capacity': 100.0,
      'color': Colors.cyan,
      'icon': Icons.opacity_rounded,
      'description': 'pH 8.5+ mineral-rich ionized alkaline water',
    },
    {
      'id': 'prod_mineral',
      'name': '19L Natural Mineral Water',
      'category': 'water',
      'unit': 'Gallons',
      'price': 55.0,
      'stock': 85.0,
      'capacity': 120.0,
      'color': Colors.teal,
      'icon': Icons.science_rounded,
      'description': 'Enriched with natural essential minerals & electrolytes',
    },
    {
      'id': 'item_slim_gallon',
      'name': '5-Gallon Slim Container',
      'category': 'container',
      'unit': 'Units',
      'price': 220.0,
      'stock': 45.0,
      'capacity': 100.0,
      'color': Colors.indigo,
      'icon': Icons.local_drink_rounded,
      'image': 'assets/images/slim_container.jpg',
      'description': 'BPA-free durable slim poly-carbonate gallon jug',
    },
    {
      'id': 'item_round_gallon',
      'name': '5-Gallon Round Container',
      'category': 'container',
      'unit': 'Units',
      'price': 200.0,
      'stock': 38.0,
      'capacity': 100.0,
      'color': Colors.deepPurple,
      'icon': Icons.crop_portrait_rounded,
      'image': 'assets/images/round_container.jpg',
      'description': 'Heavy-duty standard round water bottle',
    },
    {
      'id': 'item_electric_pump',
      'name': 'Rechargeable Electric Water Pump',
      'category': 'accessory',
      'unit': 'Pieces',
      'price': 350.0,
      'stock': 18.0,
      'capacity': 50.0,
      'color': Colors.amber,
      'icon': Icons.power_rounded,
      'description': 'USB rechargeable automatic dispenser pump',
    },
    {
      'id': 'item_manual_pump',
      'name': 'Manual Hand Press Water Pump',
      'category': 'accessory',
      'unit': 'Pieces',
      'price': 120.0,
      'stock': 25.0,
      'capacity': 60.0,
      'color': Colors.orange,
      'icon': Icons.touch_app_rounded,
      'description': 'Instant vacuum suction manual hand pump',
    },
    {
      'id': 'item_dispenser_caps',
      'name': '5-Gallon Non-Spill Caps (5-pack)',
      'category': 'accessory',
      'unit': 'Packs',
      'price': 60.0,
      'stock': 60.0,
      'capacity': 150.0,
      'color': Colors.green,
      'icon': Icons.adjust_rounded,
      'description': 'Leak-proof anti-splash silicone replacement caps',
    },
  ];

  int _emptyContainerStocks = 140;
  int _refilledContainerStocks = 90;

  int get emptyContainerStocks => _emptyContainerStocks;
  int get refilledContainerStocks => _refilledContainerStocks;

  void adjustContainerReserves({int emptyChange = 0, int refilledChange = 0}) {
    _emptyContainerStocks = max(0, _emptyContainerStocks + emptyChange);
    _refilledContainerStocks = max(0, _refilledContainerStocks + refilledChange);
    notifyListeners();
  }

  List<Map<String, dynamic>> get inventoryItems => _inventoryItems;

  List<Map<String, dynamic>> get waterProducts =>
      _inventoryItems.where((i) => i['category'] == 'water').toList();

  void addInventoryItem({
    required String name,
    required String category,
    required String unit,
    required double price,
    required double stock,
    required double capacity,
    required Color color,
    required IconData icon,
    String description = '',
  }) {
    final newItem = {
      'id': 'item_${DateTime.now().millisecondsSinceEpoch}',
      'name': name,
      'category': category,
      'unit': unit,
      'price': price,
      'stock': stock,
      'capacity': capacity,
      'color': color,
      'icon': icon,
      'description': description,
    };
    _inventoryItems.add(newItem);
    notifyListeners();
    _syncInventoryToSupabase(newItem, action: 'insert');
  }

  void addWaterProduct({
    required String name,
    required double price,
    required double stock,
    required double capacity,
    required Color color,
    required IconData icon,
    String description = '',
  }) {
    addInventoryItem(
      name: name,
      category: 'water',
      unit: 'Gallons',
      price: price,
      stock: stock,
      capacity: capacity,
      color: color,
      icon: icon,
      description: description.isNotEmpty ? description : 'Water Refill Product',
    );
  }

  void updateInventoryItem({
    required String id,
    required String name,
    required String category,
    required String unit,
    required double price,
    required double stock,
    required double capacity,
    required Color color,
    required IconData icon,
    String description = '',
  }) {
    final idx = _inventoryItems.indexWhere((p) => p['id'] == id);
    if (idx != -1) {
      _inventoryItems[idx] = {
        'id': id,
        'name': name,
        'category': category,
        'unit': unit,
        'price': price,
        'stock': stock,
        'capacity': capacity,
        'color': color,
        'icon': icon,
        'description': description,
      };
      notifyListeners();
      _syncInventoryToSupabase(_inventoryItems[idx], action: 'update');
    }
  }

  void deleteInventoryItem(String id) {
    _inventoryItems.removeWhere((p) => p['id'] == id);
    notifyListeners();
    _syncInventoryToSupabase({'id': id}, action: 'delete');
  }

  void restockInventoryItem(String id, double amount) {
    final idx = _inventoryItems.indexWhere((p) => p['id'] == id);
    if (idx != -1) {
      final capacity = (_inventoryItems[idx]['capacity'] as num).toDouble();
      final currentStock = (_inventoryItems[idx]['stock'] as num).toDouble();
      _inventoryItems[idx]['stock'] = min(capacity, currentStock + amount);
      notifyListeners();
      _syncInventoryToSupabase(_inventoryItems[idx], action: 'update');
    }
  }

  void refillWaterProduct(String id, double amount) {
    restockInventoryItem(id, amount);
  }

  void deductProductStock(String name, int qty) {
    final idx = _inventoryItems.indexWhere((p) => p['name'] == name);
    if (idx != -1) {
      final currentStock = (_inventoryItems[idx]['stock'] as num).toDouble();
      _inventoryItems[idx]['stock'] = max(0.0, currentStock - qty);
      notifyListeners();
      _syncInventoryToSupabase(_inventoryItems[idx], action: 'update');
    }
    // Also update container reserves
    adjustContainerReserves(emptyChange: qty, refilledChange: -qty);
  }

  Future<void> _syncInventoryToSupabase(Map<String, dynamic> item, {required String action}) async {
    if (!_isSupabaseConfigured) return;
    try {
      final client = Supabase.instance.client;
      if (action == 'insert') {
        await client.from('inventory').insert({
          'id': item['id'],
          'name': item['name'],
          'category': item['category'],
          'unit': item['unit'],
          'price': item['price'],
          'stock': item['stock'],
          'capacity': item['capacity'],
          'description': item['description'] ?? '',
        });
      } else if (action == 'update') {
        await client.from('inventory').update({
          'name': item['name'],
          'category': item['category'],
          'unit': item['unit'],
          'price': item['price'],
          'stock': item['stock'],
          'capacity': item['capacity'],
          'description': item['description'] ?? '',
        }).eq('id', item['id']);
      } else if (action == 'delete') {
        await client.from('inventory').delete().eq('id', item['id']);
      }
    } catch (e) {
      debugPrint('Supabase inventory sync: $e');
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

      if (fetched.isNotEmpty) {
        // Detect if there are changes compared to current in-memory orders
        bool hasChanges = _orders.length != fetched.length;
        if (!hasChanges) {
          for (int i = 0; i < fetched.length; i++) {
            if (_orders[i].id != fetched[i].id ||
                _orders[i].orderStatus != fetched[i].orderStatus ||
                _orders[i].paymentStatus != fetched[i].paymentStatus ||
                _orders[i].driverId != fetched[i].driverId) {
              hasChanges = true;
              break;
            }
          }
        }

        _orders.clear();
        _orders.addAll(fetched);
        if (hasChanges || !silent) {
          notifyListeners();
        }
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
    String? deliveryNote,
    double? latitude,
    double? longitude,
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
      deliveryNote: (deliveryNote != null && deliveryNote.trim().isNotEmpty)
          ? deliveryNote.trim()
          : null,
      latitude: latitude,
      longitude: longitude,
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
        if (newOrder.deliveryNote != null) {
          insertMap['deliveryNote'] = newOrder.deliveryNote!;
        }
        if (newOrder.latitude != null) {
          insertMap['latitude'] = newOrder.latitude!;
        }
        if (newOrder.longitude != null) {
          insertMap['longitude'] = newOrder.longitude!;
        }

        try {
          await client.from('orders').insert(insertMap);
          debugPrint('Successfully inserted order ${newOrder.id} to Supabase!');
        } catch (colErr) {
          debugPrint('Supabase initial insert failed: $colErr. Retrying with safe base columns...');
          // Remove deliveryNote if column does not exist in the database table
          insertMap.remove('deliveryNote');
          if (newOrder.deliveryNote != null && newOrder.deliveryNote!.isNotEmpty) {
            insertMap['deliveryAddress'] =
                '${newOrder.deliveryAddress} (Note: ${newOrder.deliveryNote})';
          }
          try {
            await client.from('orders').insert(insertMap);
            debugPrint('Successfully inserted order ${newOrder.id} with safe columns!');
          } catch (retryErr) {
            debugPrint('Supabase retry insert failed: $retryErr');
          }
        }
        
        // Refresh immediately with notify
        await fetchSupabaseOrders(silent: false);
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
    if (index != -1) {
      _orders[index].paymentStatus = 'Paid';
      notifyListeners();
    }

    if (_isSupabaseConfigured) {
      try {
        final client = Supabase.instance.client;
        await client
            .from('orders')
            .update({'paymentStatus': 'Paid'})
            .eq('id', orderId);
        await fetchSupabaseOrders(silent: false);
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
