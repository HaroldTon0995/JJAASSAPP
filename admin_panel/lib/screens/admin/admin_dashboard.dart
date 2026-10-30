import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';
import '../../models/order_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';
import '../../services/api_service.dart';
import '../../services/payment_service.dart';
import '../../services/report_service.dart';
import '../../services/ai_support_service.dart';
import '../../widgets/water_widgets.dart';
import '../../widgets/gcash_payment_modal.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final ApiService _apiService = ApiService();
  final PaymentService _paymentService = PaymentService();
  bool _isLoading = true;
  bool _isActionLoading = false;
  List<UserModel> _allUsers = [];
  List<UserModel> _filteredUsers = [];

  // Tab indexing maps directly to sidebar:
  // 0: Dashboard, 1: Orders, 2: Deliveries, 3: Customers, 4: Inventory, 5: Payments, 6: Reports, 7: AI Chat Support, 8: Users, 9: Settings
  int _selectedTab = 0;
  int _activeSidebarMenu = 0;

  // Search/filter states for Users
  final TextEditingController _searchController = TextEditingController();
  String _selectedRoleFilter = 'All';

  // Search/filter states for Inventory
  final TextEditingController _inventorySearchController =
      TextEditingController();

  // State variables for interactive support chat
  final List<Map<String, dynamic>> _supportMessages = [
    {
      'sender': 'AquaBot',
      'message': "Hello! I'm AquaBot 💧 How can I help you today?",
    },
  ];
  final TextEditingController _supportInputController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  bool _isChatLoading = false;

  // Sales Overview interactive state
  String _salesTimeframe =
      'This Week'; // 'This Week', 'Last 7 Days', 'This Month', 'All Time'
  int? _selectedSalesPointIndex;

  // Orders status filter
  String _activeOrderFilter = 'All';

  // Deliveries Tab States
  String _deliveriesFilter =
      'All'; // 'All', 'Active', 'Pending', 'Completed', 'Today'
  final TextEditingController _deliveriesSearchController =
      TextEditingController();
  OrderModel? _selectedDeliveryOrder;
  bool _mapSatelliteMode = false;

  // Realtime Report States
  String _reportInterval = 'Daily'; // 'Daily', 'Weekly', 'Monthly', 'Annually'
  DateTime _selectedReportDate = DateTime.now();

  // Realtime Payments Filter and Search States
  String _paymentsFilter = 'All'; // 'All', 'GCash', 'Cash on Delivery', 'Paid', 'Pending'
  final TextEditingController _paymentsSearchController = TextEditingController();

  // Realtime Live Notifications
  final List<Map<String, dynamic>> _notifications = [];

  // Realtime Live Inbox Messages
  final List<Map<String, dynamic>> _inboxMessages = [];

  // Order state tracking
  List<OrderModel> _previousOrders = [];

  // Profiles stream and state tracking
  StreamSubscription? _profilesSubscription;
  List<UserModel> _previousProfiles = [];

  void _syncRealtimeNotifications(List<OrderModel> currentOrders) {
    if (_previousOrders.isEmpty) {
      _previousOrders = List.from(currentOrders);
      _notifications.clear();
      _notifications.add({
        'id': 'system_init',
        'title': 'System Online',
        'body': 'Live transaction monitor is online.',
        'time': 'Just now',
        'icon': Icons.dns_rounded,
        'color': Colors.indigo,
        'isRead': false,
        'timestamp': DateTime.now(),
      });
      return;
    }

    final today = DateTime.now();

    for (var o in currentOrders) {
      final isNew = !_previousOrders.any((prev) => prev.id == o.id);
      if (isNew) {
        if (o.createdAt.year == today.year &&
            o.createdAt.month == today.month &&
            o.createdAt.day == today.day) {
          _notifications.insert(0, {
            'id': 'new_${o.id}',
            'title': 'New Order Placed',
            'body': '${o.customerName} ordered ${o.itemsSummary} (${o.id}).',
            'time': 'Just now',
            'icon': Icons.shopping_basket_rounded,
            'color': Colors.blue,
            'isRead': false,
            'timestamp': DateTime.now(),
          });

          // Log customer concern inbox alert for new order
          _inboxMessages.insert(0, {
            'id': 'msg_order_${o.id}',
            'sender': o.customerName,
            'snippet':
                'New Order placed (${o.id}) requesting ${o.quantity}x ${o.waterType}. Please prepare.',
            'time': 'Just now',
            'isRead': false,
            'timestamp': DateTime.now(),
          });
          // Realtime alert toast for admin
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Helpers.showSnackBar(
                context,
                '🛒 Realtime Order: ${o.customerName} placed ${o.id} (${o.itemsSummary} • ${o.paymentMethod} • ${o.paymentStatus})',
              );
            }
          });
        }
      }
    }

    for (var o in currentOrders) {
      final prevIndex = _previousOrders.indexWhere((prev) => prev.id == o.id);
      if (prevIndex != -1) {
        final prev = _previousOrders[prevIndex];

        if (prev.orderStatus != o.orderStatus) {
          IconData icon = Icons.info_outline;
          Color color = Colors.grey;
          String title = 'Order Update';
          String body =
              'Order ${o.id} status updated to ${o.orderStatus.displayName}.';

          if (o.orderStatus == OrderStatus.confirmed) {
            title = 'Order Confirmed';
            body = 'Order ${o.id} confirmed by Admin.';
            icon = Icons.assignment_turned_in_rounded;
            color = Colors.purple;
          } else if (o.orderStatus == OrderStatus.assigned) {
            title = 'Rider Assigned';
            body =
                'Driver ${o.driverName ?? "Driver"} assigned to Order ${o.id}.';
            icon = Icons.assignment_ind_rounded;
            color = const Color(0xFFF43F5E);
          } else if (o.orderStatus == OrderStatus.onDelivery) {
            title = 'Job Dispatched';
            body =
                'Driver ${o.driverName ?? "Driver"} accepted delivery for ${o.id}.';
            icon = Icons.local_shipping_rounded;
            color = Colors.cyan;
          } else if (o.orderStatus == OrderStatus.completed) {
            title = 'Delivery Completed';
            body =
                'Order ${o.id} delivered to ${o.customerName} by ${o.driverName ?? "Driver"}.';
            icon = Icons.check_circle_outline_rounded;
            color = Colors.green;
          } else if (o.orderStatus == OrderStatus.cancelled) {
            title = 'Order Cancelled';
            body = 'Order ${o.id} was cancelled.';
            icon = Icons.cancel_outlined;
            color = Colors.red;

            // Log customer cancel concern inbox alert
            _inboxMessages.insert(0, {
              'id': 'msg_cancel_${o.id}',
              'sender': o.customerName,
              'snippet':
                  'Concern: My order ${o.id} was cancelled. Can you explain why?',
              'time': 'Just now',
              'isRead': false,
              'timestamp': DateTime.now(),
            });
          }

          _notifications.insert(0, {
            'id': 'status_${o.id}_${o.orderStatus.name}',
            'title': title,
            'body': body,
            'time': 'Just now',
            'icon': icon,
            'color': color,
            'isRead': false,
            'timestamp': DateTime.now(),
          });
        }

        if (prev.paymentStatus != o.paymentStatus &&
            o.paymentStatus == 'Paid') {
          _notifications.insert(0, {
            'id': 'pay_${o.id}',
            'title': 'Payment Confirmed',
            'body':
                'Payment of ₱${o.totalAmount.toStringAsFixed(2)} confirmed for ${o.id}.',
            'time': 'Just now',
            'icon': Icons.payments_rounded,
            'color': Colors.green,
            'isRead': false,
            'timestamp': DateTime.now(),
          });

          // Realtime payment alert toast for admin
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Helpers.showSnackBar(
                context,
                '💰 Realtime Payment: ${o.customerName} paid ₱${o.totalAmount.toStringAsFixed(2)} for ${o.id} via ${o.paymentMethod}!',
              );
            }
          });
        }
      }
    }

    _notifications.retainWhere((n) {
      final ts = n['timestamp'] as DateTime?;
      if (ts == null) return true;
      return ts.year == today.year &&
          ts.month == today.month &&
          ts.day == today.day;
    });

    _inboxMessages.retainWhere((m) {
      final ts = m['timestamp'] as DateTime?;
      if (ts == null) return true;
      return ts.year == today.year &&
          ts.month == today.month &&
          ts.day == today.day;
    });

    _previousOrders = List.from(currentOrders);
  }

  void _listenToSupabaseProfiles() {
    final isSupabaseConfigured =
        AppConstants.supabaseUrl != 'YOUR_SUPABASE_PROJECT_URL' &&
        AppConstants.supabaseAnonKey != 'YOUR_SUPABASE_PROJECT_ANON_KEY';
    if (!isSupabaseConfigured) return;

    try {
      final client = Supabase.instance.client;
      _profilesSubscription = client
          .from('profiles')
          .stream(primaryKey: ['id'])
          .listen(
            (List<Map<String, dynamic>> response) {
              if (!mounted) return;
              final currentProfiles = response
                  .map((item) => UserModel.fromJson(item))
                  .toList();
              _syncProfileNotifications(currentProfiles);
            },
            onError: (e) {
              debugPrint('Supabase Realtime Profiles stream error: $e');
            },
          );
    } catch (e) {
      debugPrint('Supabase Realtime Profiles stream setup failed: $e');
    }
  }

  void _syncProfileNotifications(List<UserModel> currentProfiles) {
    if (_previousProfiles.isEmpty) {
      _previousProfiles = List.from(currentProfiles);
      setState(() {
        _allUsers = currentProfiles;
        _filteredUsers = currentProfiles;
      });
      _applyFilters();
      return;
    }

    final today = DateTime.now();

    for (var p in currentProfiles) {
      final isNew = !_previousProfiles.any((prev) => prev.id == p.id);
      if (isNew) {
        final roleLabel = p.role == UserRole.driver ? 'Driver' : 'Customer';
        _notifications.insert(0, {
          'id': 'reg_${p.id}',
          'title': 'New Registration',
          'body': 'Realtime: New $roleLabel ${p.name} registered.',
          'time': 'Just now',
          'icon': p.role == UserRole.driver
              ? Icons.local_shipping_rounded
              : Icons.person_add_rounded,
          'color': p.role == UserRole.driver ? Colors.orange : Colors.blue,
          'isRead': false,
          'timestamp': DateTime.now(),
        });

        _inboxMessages.insert(0, {
          'id': 'msg_reg_${p.id}',
          'sender': p.name,
          'snippet':
              'Hi Admin! I just completed my registration for ${p.roleDisplayName.toLowerCase()} profile.',
          'time': 'Just now',
          'isRead': false,
          'timestamp': DateTime.now(),
        });

        Helpers.showSnackBar(
          context,
          'Database Alert: New $roleLabel ${p.name} has registered!',
        );
      }
    }

    _notifications.retainWhere((n) {
      final ts = n['timestamp'] as DateTime?;
      if (ts == null) return true;
      return ts.year == today.year &&
          ts.month == today.month &&
          ts.day == today.day;
    });

    _inboxMessages.retainWhere((m) {
      final ts = m['timestamp'] as DateTime?;
      if (ts == null) return true;
      return ts.year == today.year &&
          ts.month == today.month &&
          ts.day == today.day;
    });

    setState(() {
      _allUsers = currentProfiles;
      _filteredUsers = currentProfiles;
      _previousProfiles = List.from(currentProfiles);
    });
    _applyFilters();
  }

  @override
  void initState() {
    super.initState();
    _loadAllDashboardData();
    _listenToSupabaseProfiles();
  }

  @override
  void dispose() {
    _profilesSubscription?.cancel();
    _searchController.dispose();
    _supportInputController.dispose();
    _chatScrollController.dispose();
    _paymentsSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllDashboardData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final users = await _apiService.getAdminUsers();

      if (mounted) {
        setState(() {
          _allUsers = users;
          _filteredUsers = users;
          _isLoading = false;
        });
        _applyFilters();
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(
          context,
          'Failed to sync dashboard data.',
          isError: true,
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredUsers = _allUsers.where((user) {
        final matchesQuery =
            user.name.toLowerCase().contains(query) ||
            user.email.toLowerCase().contains(query) ||
            user.role.name.toLowerCase().contains(query) ||
            (query == 'customers' && user.role == UserRole.customer);
        final matchesRole =
            _selectedRoleFilter == 'All' ||
            user.role.name.toLowerCase() == _selectedRoleFilter.toLowerCase() ||
            (_selectedRoleFilter.toLowerCase() == 'customers' &&
                user.role == UserRole.customer);
        return matchesQuery && matchesRole;
      }).toList();
    });
  }

  void _updateOrderStatus(String id, String newStatusStr) async {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    OrderStatus status = OrderStatus.pending;
    if (newStatusStr == 'Confirmed') status = OrderStatus.confirmed;
    if (newStatusStr == 'Assigned') status = OrderStatus.assigned;
    if (newStatusStr == 'On Delivery') status = OrderStatus.onDelivery;
    if (newStatusStr == 'Completed') status = OrderStatus.completed;
    if (newStatusStr == 'Cancelled') status = OrderStatus.cancelled;

    await orderProvider.updateOrderStatus(orderId: id, newStatus: status);
    if (mounted) {
      Helpers.showSnackBar(
        context,
        'Order $id status updated to $newStatusStr across system.',
      );
    }
  }

  void _sendSupportMessage(String text) async {
    if (text.trim().isEmpty) return;
    if (_isChatLoading) return; // Prevent multiple requests at once
    final userQuery = text.trim();

    setState(() {
      _supportMessages.add({'sender': 'Admin', 'message': userQuery});
      _supportInputController.clear();
      _isChatLoading = true;
      _supportMessages.add({'sender': 'AquaBot', 'message': 'Thinking...'});
    });

    _scrollToBottom();

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final user = auth.currentUser;

    try {
      final response = await AiSupportService.getChatResponse(
        query: userQuery,
        isDriver: false,
        isAdmin: true,
        userId: user?.id ?? '',
        userName: user?.name ?? 'Admin',
        orderProvider: orderProvider,
      );

      if (mounted) {
        setState(() {
          if (_supportMessages.isNotEmpty &&
              _supportMessages.last['message'] == 'Thinking...') {
            _supportMessages.removeLast();
          }
          _supportMessages.add({'sender': 'AquaBot', 'message': response});
          _isChatLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (_supportMessages.isNotEmpty &&
              _supportMessages.last['message'] == 'Thinking...') {
            _supportMessages.removeLast();
          }
          _supportMessages.add({
            'sender': 'AquaBot',
            'message':
                'Sorry, I encountered an issue retrieving a response. Please check your connection and try again.',
          });
          _isChatLoading = false;
        });
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleUpdateRole(UserModel user, UserRole newRole) async {
    setState(() {
      _isActionLoading = true;
    });

    try {
      final success = await _apiService.updateUserRole(user.id, newRole);
      if (success && mounted) {
        Helpers.showSnackBar(
          context,
          'Updated ${user.name} to ${newRole.name}.',
        );
        final updatedUsers = await _apiService.getAdminUsers();
        setState(() {
          _allUsers = updatedUsers;
        });
        _applyFilters();
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(
          context,
          'Failed to update user role.',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isActionLoading = false;
        });
      }
    }
  }

  Future<void> _handleLogout() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isWide = media.size.width >= 1100;
    const isDark = false;

    final orderProvider = Provider.of<OrderProvider>(context);
    _syncRealtimeNotifications(orderProvider.orders);

    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      drawer: (!isWide)
          ? Drawer(
              backgroundColor: Colors.white,
              child: _buildSidebar(isDark, isDrawer: true),
            )
          : null,
      appBar: isWide
          ? null
          : AppBar(
              backgroundColor: AppTheme.navyColor,
              foregroundColor: Colors.white,
              elevation: 2,
              titleSpacing: 8,
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const WaterDropletLogo(size: 28),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _getTabTitle(),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        const Text(
                          'JJAASS Water Market • Admin',
                          style: TextStyle(
                            color: Color(0xFFBFDBFE),
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.sync_rounded, color: Colors.white),
                  tooltip: 'Sync Console',
                  onPressed: _loadAllDashboardData,
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded, color: Colors.white),
                  tooltip: 'Log Out',
                  onPressed: _handleLogout,
                ),
              ],
            ),
      body: Row(
        children: [
          if (isWide) _buildSidebar(isDark),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.navyColor,
                    ),
                  )
                : Column(
                    children: [
                      if (isWide) _buildDesktopHeader(isDark),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: _buildSelectedTabContent(
                            isDark,
                            media.size.width,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopHeader(bool isDark) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.currentUser;
    final adminName = user?.name ?? 'Admin';
    final adminInitial = adminName.isNotEmpty
        ? adminName[0].toUpperCase()
        : 'A';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 14.0),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFCBD5E1),
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getTabTitle(),
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.navyColor,
                ),
              ),
              Row(
                children: [
                  const Text(
                    'Welcome back, ',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.mutedText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '$adminName!',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          Container(
            width: 300,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: TextField(
              style: const TextStyle(
                color: AppTheme.navyColor,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
              decoration: const InputDecoration(
                hintText: 'Search anything...',
                hintStyle: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: AppTheme.primaryColor,
                  size: 19,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.only(bottom: 8),
              ),
            ),
          ),
          const SizedBox(width: 24),

          // Realtime Notifications Popup
          _buildRealtimeNotificationsPopup(isDark),

          const SizedBox(width: 16),

          // Realtime Messages/Inbox Popup
          _buildRealtimeMessagesPopup(isDark),

          const SizedBox(width: 24),
          Container(
            height: 32,
            width: 1,
            color: const Color(0xFFCBD5E1),
          ),
          const SizedBox(width: 24),
          Row(
            children: [
              CircleAvatar(
                radius: 19,
                backgroundColor: AppTheme.navyColor,
                child: Text(
                  adminInitial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    adminName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      color: AppTheme.navyColor,
                    ),
                  ),
                  const Text(
                    'Administrator',
                    style: TextStyle(
                      color: AppTheme.mutedText,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRealtimeNotificationsPopup(bool isDark) {
    final unreadCount = _notifications
        .where((n) => !(n['isRead'] as bool))
        .length;

    return PopupMenuButton<String>(
      tooltip: 'System Notifications',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      offset: const Offset(0, 48),
      color: isDark ? AppTheme.darkSurface : Colors.white,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : const Color(0xFFF8FAFC),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF64748B),
              size: 20,
            ),
          ),
          if (unreadCount > 0)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Center(
                  child: Text(
                    '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      onSelected: (val) {
        if (val == 'mark_read') {
          setState(() {
            for (var n in _notifications) {
              n['isRead'] = true;
            }
          });
          Helpers.showSnackBar(context, 'All notifications marked as read.');
        }
      },
      itemBuilder: (context) {
        final List<PopupMenuEntry<String>> items = [];

        // Header
        items.add(
          PopupMenuItem<String>(
            enabled: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Notifications',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: AppTheme.primaryColor,
                    fontSize: 14,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop('mark_read');
                  },
                  child: const Text(
                    'Read All',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
        items.add(const PopupMenuDivider(height: 1));

        if (_notifications.isEmpty) {
          items.add(
            const PopupMenuItem<String>(
              enabled: false,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Text(
                    'No notifications yet',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ),
            ),
          );
        } else {
          for (var i = 0; i < min(_notifications.length, 5); i++) {
            final n = _notifications[i];
            final bool isRead = n['isRead'] as bool;
            items.add(
              PopupMenuItem<String>(
                value: 'nt_${n['id']}',
                onTap: () {
                  setState(() {
                    n['isRead'] = true;
                  });
                },
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: (n['color'] as Color).withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        n['icon'] as IconData,
                        color: n['color'] as Color,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                n['title'] as String,
                                style: TextStyle(
                                  fontWeight: isRead
                                      ? FontWeight.bold
                                      : FontWeight.w900,
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF1E293B),
                                ),
                              ),
                              Text(
                                n['time'] as String,
                                style: TextStyle(
                                  color: const Color(0xFF64748B),
                                  fontSize: 8,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            n['body'] as String,
                            style: TextStyle(
                              fontSize: 10,
                              color: isRead
                                  ? Colors.grey
                                  : (isDark
                                        ? Colors.grey.shade300
                                        : const Color(0xFF475569)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
            if (i < 4 && i < _notifications.length - 1) {
              items.add(const PopupMenuDivider(height: 1));
            }
          }
        }
        return items;
      },
    );
  }

  Widget _buildRealtimeMessagesPopup(bool isDark) {
    final unreadCount = _inboxMessages
        .where((m) => !(m['isRead'] as bool))
        .length;

    return PopupMenuButton<String>(
      tooltip: 'Customer Messages',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      offset: const Offset(0, 48),
      color: isDark ? AppTheme.darkSurface : Colors.white,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : const Color(0xFFF8FAFC),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline_rounded,
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF64748B),
              size: 20,
            ),
          ),
          if (unreadCount > 0)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Center(
                  child: Text(
                    '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      onSelected: (val) {
        if (val.startsWith('msg_')) {
          setState(() {
            final msgId = val.replaceFirst('msg_', '');
            final msgIndex = _inboxMessages.indexWhere(
              (m) => m['id'] == msgId || 'msg_${m['id']}' == val,
            );
            if (msgIndex != -1) {
              _inboxMessages[msgIndex]['isRead'] = true;
            }
            // Navigate to AI Chat Support Tab (Tab 7)
            _selectedTab = 7;
            _activeSidebarMenu = 7;
          });
        }
      },
      itemBuilder: (context) {
        final List<PopupMenuEntry<String>> items = [];

        // Header
        items.add(
          const PopupMenuItem<String>(
            enabled: false,
            child: Text(
              'Inbox Messages',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: AppTheme.primaryColor,
                fontSize: 14,
              ),
            ),
          ),
        );
        items.add(const PopupMenuDivider(height: 1));

        if (_inboxMessages.isEmpty) {
          items.add(
            const PopupMenuItem<String>(
              enabled: false,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Text(
                    'No messages yet',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ),
            ),
          );
        } else {
          for (var i = 0; i < min(_inboxMessages.length, 5); i++) {
            final m = _inboxMessages[i];
            final bool isRead = m['isRead'] as bool;
            items.add(
              PopupMenuItem<String>(
                value: 'msg_${m['id']}',
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: AppTheme.primaryColor.withValues(
                        alpha: 0.1,
                      ),
                      child: Text(
                        (m['sender'] as String).substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                m['sender'] as String,
                                style: TextStyle(
                                  fontWeight: isRead
                                      ? FontWeight.bold
                                      : FontWeight.w900,
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF1E293B),
                                ),
                              ),
                              Text(
                                m['time'] as String,
                                style: TextStyle(
                                  color: const Color(0xFF64748B),
                                  fontSize: 8,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            m['snippet'] as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: isRead
                                  ? Colors.grey
                                  : (isDark
                                        ? Colors.grey.shade300
                                        : const Color(0xFF475569)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
            if (i < 4 && i < _inboxMessages.length - 1) {
              items.add(const PopupMenuDivider(height: 1));
            }
          }
        }
        return items;
      },
    );
  }

  String _getTabTitle() {
    switch (_selectedTab) {
      case 0:
        return 'System Performance Overview';
      case 1:
        return 'Orders Management';
      case 2:
        return 'Deliveries Fleet';
      case 3:
        return 'Users';
      case 4:
        return 'Inventory & Reserves';
      case 5:
        return 'Payments Transactions';
      case 6:
        return 'Analytics & Reports';
      case 7:
        return 'AquaBot AI Support';
      case 8:
        return 'Role Permissions';
      case 9:
        return 'System Settings';
      default:
        return 'Admin Portal';
    }
  }

  Widget _buildSidebar(bool isDark, {bool isDrawer = false}) {
    final menuItems = [
      {'title': 'Dashboard', 'icon': Icons.home_rounded},
      {'title': 'Orders', 'icon': Icons.shopping_bag_rounded},
      {'title': 'Deliveries', 'icon': Icons.local_shipping_rounded},
      {'title': 'Users', 'icon': Icons.people_alt_rounded},
      {'title': 'Inventory', 'icon': Icons.inventory_2_rounded},
      {'title': 'Payments', 'icon': Icons.payment_rounded},
      {'title': 'Reports', 'icon': Icons.analytics_rounded},
      {'title': 'AI Chat Support', 'icon': Icons.chat_rounded},
      {'title': 'Role Permissions', 'icon': Icons.manage_accounts_rounded},
      {'title': 'Settings', 'icon': Icons.settings_rounded},
    ];

    return Container(
      width: 260,
      height: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: Color(0xFFCBD5E1), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(
              left: 20,
              top: 24,
              right: 20,
              bottom: 18,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border(
                bottom: BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.secondaryColor.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: const WaterDropletLogo(size: 40),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'JJAASS',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.navyColor,
                        letterSpacing: 1.4,
                      ),
                    ),
                    Text(
                      'WATER MARKET',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryColor,
                        letterSpacing: 1.6,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: menuItems.length,
              itemBuilder: (context, index) {
                final item = menuItems[index];
                final bool isSelected = _activeSidebarMenu == index;
                return _SidebarItemTile(
                  icon: item['icon'] as IconData,
                  title: item['title'] as String,
                  isSelected: isSelected,
                  onTap: () {
                    setState(() {
                      _activeSidebarMenu = index;
                      _selectedTab = index;
                    });
                    if (isDrawer) {
                      Navigator.of(context).pop();
                    }
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14.0),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.secondaryColor.withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
              child: const Column(
                children: [
                  WaterJugIllustration(width: 68, height: 76),
                  SizedBox(height: 8),
                  Text(
                    'Fresh & Pure Water',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.navyColor,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Admin Management Console',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.mutedText,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _SidebarItemTile(
            icon: Icons.logout_rounded,
            title: 'Log Out',
            isSelected: false,
            textColor: const Color(0xFFDC2626),
            onTap: _handleLogout,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildSelectedTabContent(bool isDark, double width) {
    switch (_selectedTab) {
      case 0:
        return _buildOverviewTab(isDark, width);
      case 1:
        return _buildOrdersTab(isDark);
      case 2:
        return _buildDeliveriesTab(isDark);
      case 3:
        return _buildCustomersTab(isDark);
      case 4:
        return _buildInventoryTab(isDark);
      case 5:
        return _buildPaymentsTab(isDark);
      case 6:
        return _buildReportsTab(isDark);
      case 7:
        return _buildSupportTab(isDark);
      case 8:
        return _buildUsersTab(isDark);
      case 9:
        return _buildSettingsTab(isDark);
      default:
        return _buildOverviewTab(isDark, width);
    }
  }

  // TAB 0: OVERVIEW/DASHBOARD
  Widget _buildOverviewTab(bool isDark, double screenWidth) {
    final bool isDesktop = screenWidth >= 1100;
    final orderProvider = Provider.of<OrderProvider>(context);
    final orders = orderProvider.orders;
    final totalRevenue = orderProvider.getTotalRevenue();
    final activeDeliveries = orderProvider.getActiveDeliveriesCount();

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats Row
          LayoutBuilder(
            builder: (context, constraints) {
              final double width = constraints.maxWidth;
              final crossCount = width > 1000 ? 4 : (width > 600 ? 2 : 1);
              return GridView.count(
                crossAxisCount: crossCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: width > 1000 ? 1.6 : 1.8,
                children: [
                  _buildStatCard(
                    'Total Orders',
                    '${orders.length}',
                    '18% from last week',
                    Icons.local_drink_rounded,
                    const Color(0xFF0284C7),
                    isDark,
                    isUpTrend: true,
                  ),
                  _buildStatCard(
                    'Active Deliveries',
                    '$activeDeliveries',
                    'Out for delivery',
                    Icons.local_shipping_rounded,
                    const Color(0xFF0284C7),
                    isDark,
                    isUpTrend: true,
                  ),
                  _buildStatCard(
                    'Total Users',
                    '${_allUsers.length}',
                    'Customers & Drivers',
                    Icons.group_rounded,
                    const Color(0xFF0EA5E9),
                    isDark,
                    isUpTrend: true,
                  ),
                  _buildStatCard(
                    'Total Revenue',
                    '₱${totalRevenue.toStringAsFixed(2)}',
                    'Gross sales',
                    Icons.payments_rounded,
                    const Color(0xFF10B981),
                    isDark,
                    isUpTrend: true,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // Main Charts and Orders Grid
          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _buildSalesOverviewCard(isDark)),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: _buildRecentOrdersListCard(isDark)),
              ],
            )
          else
            Column(
              children: [
                _buildSalesOverviewCard(isDark),
                const SizedBox(height: 16),
                _buildRecentOrdersListCard(isDark),
              ],
            ),
          const SizedBox(height: 20),

          // Bottom Table & Quick Actions Layout
          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: _buildRecentOrdersTableCard(isDark)),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      _buildQuickActionsCard(isDark),
                      const SizedBox(height: 16),
                      _buildAiSupportCard(isDark),
                    ],
                  ),
                ),
              ],
            )
          else
            Column(
              children: [
                _buildRecentOrdersTableCard(isDark),
                const SizedBox(height: 16),
                _buildQuickActionsCard(isDark),
                const SizedBox(height: 16),
                _buildAiSupportCard(isDark),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    String trend,
    IconData icon,
    Color color,
    bool isDark, {
    required bool isUpTrend,
  }) {
    return Container(
      padding: const EdgeInsets.all(18.0),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isUpTrend
                        ? const Color(0xFF10B981).withValues(alpha: isDark ? 0.2 : 0.1)
                        : Colors.red.withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isUpTrend
                          ? const Color(0xFF10B981).withValues(alpha: isDark ? 0.45 : 0.25)
                          : Colors.red.withValues(alpha: isDark ? 0.45 : 0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isUpTrend
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        color: isUpTrend ? const Color(0xFF10B981) : Colors.red,
                        size: 12,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        trend,
                        style: TextStyle(
                          color: isUpTrend
                              ? (isDark ? const Color(0xFF34D399) : const Color(0xFF047857))
                              : Colors.red,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.2 : 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withValues(alpha: isDark ? 0.4 : 0.2),
              ),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
        ],
      ),
    );
  }

  // Helper to compute live Sales Overview data based on selected timeframe
  Map<String, dynamic> _computeSalesOverviewData(List<OrderModel> orders) {
    final now = DateTime.now();
    List<double> dataPoints = [];
    List<String> labels = [];

    if (_salesTimeframe == 'This Week') {
      final currentWeekday = now.weekday; // 1 to 7
      final monday = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: currentWeekday - 1));
      labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      dataPoints = List.filled(7, 0.0);

      for (var order in orders) {
        final orderDate = order.createdAt;
        final diffDays = orderDate.difference(monday).inDays;
        if (diffDays >= 0 &&
            diffDays < 7 &&
            orderDate.isAfter(monday.subtract(const Duration(seconds: 1)))) {
          final dayIdx = (orderDate.weekday - 1).clamp(0, 6);
          dataPoints[dayIdx] += order.totalAmount;
        }
      }
    } else if (_salesTimeframe == 'Last 7 Days') {
      labels = [];
      dataPoints = List.filled(7, 0.0);
      final daysOfWeek = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      for (int i = 6; i >= 0; i--) {
        final d = now.subtract(Duration(days: i));
        if (i == 0) {
          labels.add('Today');
        } else {
          labels.add(daysOfWeek[d.weekday - 1]);
        }
      }
      for (var order in orders) {
        final diffDays = now.difference(order.createdAt).inDays;
        if (diffDays >= 0 && diffDays < 7) {
          final idx = 6 - diffDays;
          if (idx >= 0 && idx < 7) {
            dataPoints[idx] += order.totalAmount;
          }
        }
      }
    } else if (_salesTimeframe == 'This Month') {
      labels = ['Week 1', 'Week 2', 'Week 3', 'Week 4'];
      dataPoints = List.filled(4, 0.0);

      for (var order in orders) {
        if (order.createdAt.year == now.year &&
            order.createdAt.month == now.month) {
          final day = order.createdAt.day;
          final weekIdx = ((day - 1) ~/ 7).clamp(0, 3);
          dataPoints[weekIdx] += order.totalAmount;
        }
      }
    } else {
      // 'All Time' -> Last 6 Months
      labels = [];
      dataPoints = List.filled(6, 0.0);
      final monthNames = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      for (int i = 5; i >= 0; i--) {
        final m = DateTime(now.year, now.month - i, 1);
        labels.add(monthNames[m.month - 1]);
      }
      for (var order in orders) {
        final monthsAgo =
            (now.year - order.createdAt.year) * 12 +
            (now.month - order.createdAt.month);
        if (monthsAgo >= 0 && monthsAgo < 6) {
          final idx = 5 - monthsAgo;
          if (idx >= 0 && idx < 6) {
            dataPoints[idx] += order.totalAmount;
          }
        }
      }
    }

    return {'dataPoints': dataPoints, 'labels': labels};
  }

  Widget _buildSalesOverviewCard(bool isDark) {
    final orderProvider = Provider.of<OrderProvider>(context);
    final salesInfo = _computeSalesOverviewData(orderProvider.orders);
    final List<double> dataPoints = salesInfo['dataPoints'] as List<double>;
    final List<String> labels = salesInfo['labels'] as List<String>;

    return Container(
      padding: const EdgeInsets.all(20.0),
      height: 310,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sales Overview',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              PopupMenuButton<String>(
                initialValue: _salesTimeframe,
                tooltip: 'Select Timeframe',
                onSelected: (val) {
                  setState(() {
                    _salesTimeframe = val;
                    _selectedSalesPointIndex = null;
                  });
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                color: isDark ? AppTheme.darkSurface : Colors.white,
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'This Week',
                    child: Text('This Week (Mon-Sun)'),
                  ),
                  const PopupMenuItem(
                    value: 'Last 7 Days',
                    child: Text('Last 7 Days'),
                  ),
                  const PopupMenuItem(
                    value: 'This Month',
                    child: Text('This Month'),
                  ),
                  const PopupMenuItem(
                    value: 'All Time',
                    child: Text('All Time (6 Months)'),
                  ),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        _salesTimeframe,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? Colors.white70
                              : const Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 14,
                        color: isDark
                            ? Colors.white70
                            : const Color(0xFF475569),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SizedBox(
              width: double.infinity,
              child: SalesOverviewLineChart(
                dataPoints: dataPoints,
                labels: labels,
                selectedIndex: _selectedSalesPointIndex,
                isDark: isDark,
                onPointSelected: (idx) {
                  setState(() {
                    _selectedSalesPointIndex = idx;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: labels.asMap().entries.map((entry) {
              final idx = entry.key;
              final day = entry.value;
              final isSelected = _selectedSalesPointIndex == idx;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedSalesPointIndex = idx;
                  });
                },
                child: Text(
                  day,
                  style: TextStyle(
                    fontSize: 11,
                    color: isSelected
                        ? AppTheme.primaryColor
                        : (isDark ? Colors.white38 : const Color(0xFF64748B)),
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }


  Widget _buildRecentOrdersListCard(bool isDark) {
    final orderProvider = Provider.of<OrderProvider>(context);
    final orders = orderProvider.orders;

    return Container(
      padding: const EdgeInsets.all(20.0),
      height: 310,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Orders',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _selectedTab = 1),
                child: Text(
                  'View All',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF38BDF8) : AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: min(orders.length, 5),
              itemBuilder: (context, index) {
                final order = orders[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: order.orderStatus.color.withValues(
                            alpha: isDark ? 0.25 : 0.1,
                          ),
                          child: Icon(
                            Icons.person,
                            size: 14,
                            color: order.orderStatus.color,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                order.id,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                                ),
                              ),
                              Text(
                                '${order.customerName} • ${order.itemsSummary}',
                                style: TextStyle(
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  fontSize: 10,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: order.orderStatus.color.withValues(
                                  alpha: isDark ? 0.25 : 0.1,
                                ),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: order.orderStatus.color.withValues(
                                    alpha: isDark ? 0.5 : 0.25,
                                  ),
                                ),
                              ),
                              child: Text(
                                order.orderStatus.displayName,
                                style: TextStyle(
                                  color: order.orderStatus.color,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              order.createdAt.toString().split(' ')[0],
                              style: TextStyle(
                                color: isDark ? const Color(0xFF64748B) : const Color(0xFF475569),
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentOrdersTableCard(bool isDark) {
    final orderProvider = Provider.of<OrderProvider>(context);
    final orders = orderProvider.orders;

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Orders Details',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                ),
              ),
              OutlinedButton(
                onPressed: () => setState(() => _selectedTab = 1),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Row(
                  children: const [
                    Text(
                      'View All Orders',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 12,
                      color: Color(0xFF64748B),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 28,
              horizontalMargin: 0,
              headingRowHeight: 40,
              dataRowMinHeight: 48,
              dataRowMaxHeight: 48,
              columns: const [
                DataColumn(
                  label: Text(
                    'Order ID',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Customer',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Products',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Address',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Status',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Total',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Date',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
              rows: orders.map((data) {
                return DataRow(
                  cells: [
                    DataCell(
                      Text(
                        data.id,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        data.customerName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        data.itemsSummary,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        data.deliveryAddress,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: data.orderStatus.color.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: data.orderStatus.color.withValues(
                              alpha: 0.15,
                            ),
                          ),
                        ),
                        child: Text(
                          data.orderStatus.displayName,
                          style: TextStyle(
                            color: data.orderStatus.color,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        data.formattedTotal,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        data.createdAt.toString().split(' ')[0],
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.1,
            children: [
              _buildQuickActionItem(
                'New Order',
                Icons.add_shopping_cart_rounded,
                const Color(0xFF0284C7),
                () => setState(() => _selectedTab = 1),
              ),
              _buildQuickActionItem(
                'Add Customer',
                Icons.person_add_alt_1_rounded,
                const Color(0xFF0284C7),
                () => setState(() => _selectedTab = 3),
              ),
              _buildQuickActionItem(
                'New Delivery',
                Icons.local_shipping_rounded,
                const Color(0xFF0EA5E9),
                () => setState(() => _selectedTab = 2),
              ),
              _buildQuickActionItem(
                'Add Inventory',
                Icons.add_box_rounded,
                const Color(0xFF10B981),
                () => setState(() => _selectedTab = 4),
              ),
              _buildQuickActionItem(
                'View Reports',
                Icons.analytics_rounded,
                const Color(0xFF6366F1),
                () => setState(() => _selectedTab = 6),
              ),
              _buildQuickActionItem(
                'Payments',
                Icons.payments_rounded,
                const Color(0xFFEC4899),
                () => setState(() => _selectedTab = 5),
              ),
              _buildQuickActionItem(
                'AI Support',
                Icons.support_agent_rounded,
                const Color(0xFF8B5CF6),
                () => setState(() => _selectedTab = 7),
              ),
              _buildQuickActionItem(
                'Users',
                Icons.people_alt_rounded,
                const Color(0xFF64748B),
                () => setState(() => _selectedTab = 8),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionItem(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.1), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiSupportCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(
                Icons.psychology_rounded,
                color: AppTheme.primaryColor,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'AI Chat Support',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(12),
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              border: Border.all(color: const Color(0xFFE2F0F3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 12,
                  backgroundColor: AppTheme.primaryColor,
                  child: Icon(Icons.adb_rounded, size: 12, color: Colors.white),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'AquaBot',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Hello! I\'m AquaBot 💧 How can I help you today?',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF475569),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: TextField(
                    controller: _supportInputController,
                    onSubmitted: _sendSupportMessage,
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Type your message...',
                      hintStyle: TextStyle(color: const Color(0xFF64748B)),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.only(bottom: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  onPressed: () =>
                      _sendSupportMessage(_supportInputController.text),
                  icon: const Icon(
                    Icons.send_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Dialog helper to create a New Order (Delivery or Store Pickup)
  void _showCreateOrderDialog(bool isDark) {
    final customersList = _allUsers
        .where((u) => u.role == UserRole.customer)
        .toList();
    final driversList = _allUsers
        .where((u) => u.role == UserRole.driver)
        .toList();
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);

    // Fulfillment choice: 'Delivery' vs 'Pickup'
    String fulfillmentType = 'Delivery';

    // Customer mode: isRegistered vs isUnregistered
    bool isRegistered = false;
    UserModel? selectedCustomer;

    // Delivery Driver selection (only for Delivery)
    UserModel? selectedDriver;
    if (driversList.isNotEmpty) {
      selectedDriver = driversList.first;
    }

    final nameController = TextEditingController();
    final phoneController = TextEditingController(text: '+63 ');
    final addressController = TextEditingController();
    final qtyController = TextEditingController(text: '1');

    String selectedWaterType = orderProvider.waterProducts.isNotEmpty
        ? (orderProvider.waterProducts.first['name'] as String)
        : '19L Purified';
    double pricePerUnit = orderProvider.waterProducts.isNotEmpty
        ? (orderProvider.waterProducts.first['price'] as double)
        : 50.0;
    String selectedPaymentMethod = 'Cash on Delivery';
    String selectedPaymentStatus = 'Pending';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDelivery = fulfillmentType == 'Delivery';

            return AlertDialog(
              backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.add_shopping_cart_rounded,
                      color: AppTheme.primaryColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Create New Order',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 520,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. FULFILLMENT TYPE TOGGLE (Delivery vs Store Pickup)
                      Text(
                        'ORDER FULFILLMENT TYPE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setDialogState(() {
                                  fulfillmentType = 'Delivery';
                                  if (addressController.text.contains('Store Pickup')) {
                                    addressController.clear();
                                  }
                                  if (selectedPaymentMethod == 'Cash') {
                                    selectedPaymentMethod = 'Cash on Delivery';
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                                decoration: BoxDecoration(
                                  color: isDelivery
                                      ? AppTheme.primaryColor.withValues(alpha: 0.1)
                                      : (isDark ? Colors.white10 : const Color(0xFFF8FAFC)),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isDelivery
                                        ? AppTheme.primaryColor
                                        : (isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                                    width: isDelivery ? 2.0 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.local_shipping_rounded,
                                      size: 20,
                                      color: isDelivery ? AppTheme.primaryColor : Colors.grey,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Home Delivery',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: isDelivery ? AppTheme.primaryColor : (isDark ? Colors.white70 : const Color(0xFF1E293B)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setDialogState(() {
                                  fulfillmentType = 'Pickup';
                                  addressController.text = 'Store Pickup / Walk-in (JJAASS Water Station)';
                                  if (selectedPaymentMethod == 'Cash on Delivery') {
                                    selectedPaymentMethod = 'Cash';
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                                decoration: BoxDecoration(
                                  color: !isDelivery
                                      ? const Color(0xFF10B981).withValues(alpha: 0.1)
                                      : (isDark ? Colors.white10 : const Color(0xFFF8FAFC)),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: !isDelivery
                                        ? const Color(0xFF10B981)
                                        : (isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                                    width: !isDelivery ? 2.0 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.storefront_rounded,
                                      size: 20,
                                      color: !isDelivery ? const Color(0xFF10B981) : Colors.grey,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Store Pickup / Walk-in',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: !isDelivery ? const Color(0xFF10B981) : (isDark ? Colors.white70 : const Color(0xFF1E293B)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // 2. CUSTOMER DETAILS (Registered vs Unregistered)
                      Text(
                        'CUSTOMER INFORMATION',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ChoiceChip(
                            label: const Text('Unregistered / Walk-in Customer'),
                            selected: !isRegistered,
                            onSelected: (val) {
                              setDialogState(() {
                                isRegistered = false;
                                selectedCustomer = null;
                                nameController.clear();
                                phoneController.text = '+63 ';
                                if (isDelivery) {
                                  addressController.clear();
                                }
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Registered Customer Account'),
                            selected: isRegistered,
                            onSelected: (val) {
                              setDialogState(() {
                                isRegistered = true;
                                if (customersList.isNotEmpty) {
                                  selectedCustomer = customersList.first;
                                  nameController.text = selectedCustomer!.name;
                                  phoneController.text = '+63 912 345 6789';
                                }
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (isRegistered) ...[
                        if (customersList.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 6.0),
                            child: Text(
                              'No registered customer accounts found. You can enter details manually below.',
                              style: TextStyle(color: Colors.orange, fontSize: 12),
                            ),
                          )
                        else
                          DropdownButtonFormField<UserModel>(
                            initialValue: selectedCustomer,
                            dropdownColor: isDark ? AppTheme.darkSurface : Colors.white,
                            decoration: const InputDecoration(
                              labelText: 'Select Registered Customer',
                              prefixIcon: Icon(Icons.account_circle_rounded),
                            ),
                            items: customersList.map((cust) {
                              return DropdownMenuItem<UserModel>(
                                value: cust,
                                child: Text('${cust.name} (${cust.email})'),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() {
                                  selectedCustomer = val;
                                  nameController.text = val.name;
                                });
                              }
                            },
                          ),
                        const SizedBox(height: 12),
                      ],

                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Customer Full Name *',
                          prefixIcon: Icon(Icons.person),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Contact Phone Number',
                          prefixIcon: Icon(Icons.phone),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: addressController,
                        enabled: isDelivery,
                        decoration: InputDecoration(
                          labelText: isDelivery ? 'Delivery Address (House no., street, brgy.) *' : 'Pickup Location',
                          prefixIcon: Icon(isDelivery ? Icons.location_on : Icons.storefront_rounded),
                          helperText: !isDelivery ? 'Store pickup orders are collected at the station' : null,
                        ),
                      ),
                      const SizedBox(height: 18),

                      // 3. DRIVER ASSIGNMENT (Only shown for Home Delivery)
                      if (isDelivery) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.delivery_dining_rounded,
                                    color: Color(0xFF8B5CF6),
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'ASSIGN DELIVERY DRIVER',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF7C3AED),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              if (driversList.isEmpty)
                                const Text(
                                  'No registered drivers found. The order will be created as Confirmed (Open for dispatch).',
                                  style: TextStyle(fontSize: 12, color: Color(0xFF7C3AED)),
                                )
                              else
                                DropdownButtonFormField<UserModel?>(
                                  initialValue: selectedDriver,
                                  dropdownColor: isDark ? AppTheme.darkSurface : Colors.white,
                                  decoration: const InputDecoration(
                                    labelText: 'Select Driver to Dispatch',
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  items: [
                                    const DropdownMenuItem<UserModel?>(
                                      value: null,
                                      child: Text('Leave Unassigned (Open for Drivers to Accept)'),
                                    ),
                                    ...driversList.map((d) {
                                      return DropdownMenuItem<UserModel?>(
                                        value: d,
                                        child: Text('🛵 ${d.name} (${d.email})'),
                                      );
                                    }),
                                  ],
                                  onChanged: (val) {
                                    setDialogState(() {
                                      selectedDriver = val;
                                    });
                                  },
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.25)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline_rounded, color: Color(0xFF059669), size: 18),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Store Pickup: No delivery rider will be assigned.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF047857),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],

                      // 4. ORDER & PRODUCT DETAILS
                      Text(
                        'PRODUCTS & PAYMENT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: DropdownButtonFormField<String>(
                              initialValue: selectedWaterType,
                              dropdownColor: isDark ? AppTheme.darkSurface : Colors.white,
                              decoration: const InputDecoration(labelText: 'Water Product'),
                              items: orderProvider.waterProducts.map((prod) {
                                final name = prod['name'] as String;
                                final price = prod['price'] as double;
                                return DropdownMenuItem<String>(
                                  value: name,
                                  child: Text('$name (₱${price.toStringAsFixed(0)})'),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setDialogState(() {
                                    selectedWaterType = val;
                                    final match = orderProvider.waterProducts.firstWhere((p) => p['name'] == val);
                                    pricePerUnit = match['price'] as double;
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: qtyController,
                              keyboardType: TextInputType.number,
                              onChanged: (val) => setDialogState(() {}),
                              decoration: const InputDecoration(
                                labelText: 'Quantity',
                                prefixIcon: Icon(Icons.water_drop_rounded),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: selectedPaymentMethod,
                              dropdownColor: isDark ? AppTheme.darkSurface : Colors.white,
                              decoration: const InputDecoration(labelText: 'Payment Method'),
                              items: [
                                const DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                                const DropdownMenuItem(value: 'GCash', child: Text('GCash')),
                                if (isDelivery)
                                  const DropdownMenuItem(value: 'Cash on Delivery', child: Text('Cash on Delivery (COD)')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setDialogState(() {
                                    selectedPaymentMethod = val;
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: selectedPaymentStatus,
                              dropdownColor: isDark ? AppTheme.darkSurface : Colors.white,
                              decoration: const InputDecoration(labelText: 'Payment Status'),
                              items: const [
                                DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                                DropdownMenuItem(value: 'Paid', child: Text('Paid')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setDialogState(() {
                                    selectedPaymentStatus = val;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Builder(
                        builder: (context) {
                          final qty = int.tryParse(qtyController.text) ?? 1;
                          final total = qty * pricePerUnit;
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total Order Amount:',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                Text(
                                  '₱${total.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final phone = phoneController.text.trim();
                    String address = addressController.text.trim();
                    final qty = int.tryParse(qtyController.text) ?? 1;

                    if (name.isEmpty) {
                      Helpers.showSnackBar(context, 'Please enter customer name.', isError: true);
                      return;
                    }
                    if (isDelivery && address.isEmpty) {
                      Helpers.showSnackBar(context, 'Please enter delivery address for home delivery.', isError: true);
                      return;
                    }
                    if (!isDelivery && address.isEmpty) {
                      address = 'Store Pickup / Walk-in (JJAASS Water Station)';
                    }

                    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
                    final custId = isRegistered && selectedCustomer != null
                        ? selectedCustomer!.id
                        : 'usr_walkin_guest';

                    // Determine order status & driver assignment based on user request:
                    // If Delivery: Confirm & Assign driver if selected (OrderStatus.assigned), or Confirmed
                    // If Pickup: Confirmed, and NO rider assigned
                    final OrderStatus orderStatus = isDelivery
                        ? (selectedDriver != null ? OrderStatus.assigned : OrderStatus.confirmed)
                        : OrderStatus.confirmed;

                    final String? driverId = isDelivery ? selectedDriver?.id : null;
                    final String? driverName = isDelivery
                        ? selectedDriver?.name
                        : 'Not Needed (Walk-in/Pickup)';

                    try {
                      final newOrder = await orderProvider.placeOrder(
                        customerId: custId,
                        customerName: name,
                        customerPhone: phone.isNotEmpty ? phone : '+63 Guest',
                        deliveryAddress: address,
                        waterType: selectedWaterType,
                        quantity: qty,
                        pricePerUnit: pricePerUnit,
                        paymentMethod: selectedPaymentMethod,
                        paymentStatus: selectedPaymentStatus,
                        orderStatus: orderStatus,
                        driverId: driverId,
                        driverName: driverName,
                      );

                      if (context.mounted) {
                        Navigator.of(context).pop();
                        final String successMsg = isDelivery
                            ? (selectedDriver != null
                                ? 'Order ${newOrder.id} created & assigned to ${selectedDriver!.name}!'
                                : 'Order ${newOrder.id} created for delivery (confirmed)!')
                            : 'Store pickup order ${newOrder.id} created successfully!';
                        Helpers.showSnackBar(context, successMsg);

                        if (selectedPaymentMethod == 'GCash' && selectedPaymentStatus == 'Pending') {
                          _showGcashPaymentDialog(newOrder, isDark);
                        }
                      }
                    } catch (e) {
                      if (context.mounted) {
                        Helpers.showSnackBar(context, 'Failed to create order: $e', isError: true);
                      }
                    }
                  },
                  icon: const Icon(Icons.check_circle_rounded, size: 16),
                  label: const Text('Confirm & Create Order'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // TAB 1: ORDERS MANAGEMENT (Interactive Order status updater)
  Widget _buildOrdersTab(bool isDark) {
    final orderProvider = Provider.of<OrderProvider>(context);
    final allOrders = orderProvider.orders;

    final filtered = _activeOrderFilter == 'All'
        ? allOrders
        : allOrders
              .where((o) => o.orderStatus.displayName == _activeOrderFilter)
              .toList();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Orders Management Log',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showCreateOrderDialog(isDark),
                icon: const Icon(
                  Icons.add_rounded,
                  size: 16,
                  color: Colors.white,
                ),
                label: const Text(
                  'New Order',
                  style: TextStyle(fontSize: 12, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Filter Tabs
          Row(
            children:
                ['All', 'Pending', 'On Delivery', 'Completed', 'Cancelled'].map(
                  (status) {
                    final isSel = _activeOrderFilter == status;
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(status),
                        selected: isSel,
                        selectedColor: AppTheme.primaryColor,
                        labelStyle: TextStyle(
                          color: isSel ? Colors.white : Colors.grey.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        onSelected: (val) {
                          setState(() {
                            _activeOrderFilter = status;
                          });
                        },
                      ),
                    );
                  },
                ).toList(),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('No orders match this status.'))
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final order = filtered[index];
                      final bool isPending =
                          order.orderStatus == OrderStatus.pending;
                      return PulsingBorder(
                        active: isPending,
                        color: Colors.orange,
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      order.id,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: order.orderStatus.color
                                            .withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: order.orderStatus.color
                                              .withValues(alpha: 0.2),
                                        ),
                                      ),
                                      child: Text(
                                        order.orderStatus.displayName,
                                        style: TextStyle(
                                          color: order.orderStatus.color,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Customer: ${order.customerName} (${order.customerPhone})',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text('Products: ${order.itemsSummary}'),
                                Text(
                                  'Delivery Address: ${order.deliveryAddress}',
                                ),
                                if (order.deliveryNote != null)
                                  Container(
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 6,
                                    ),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF3C7),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: const Color(0xFFF59E0B),
                                      ),
                                    ),
                                    child: Text(
                                      '📝 Customer Note: ${order.deliveryNote}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF78350F),
                                      ),
                                    ),
                                  ),
                                Text(
                                  'Assigned Driver: ${order.requiresDriver ? (order.driverName ?? "Unassigned") : "Not Needed (Walk-in/Pickup)"}',
                                ),
                                Row(
                                  children: [
                                    Text(
                                      'Total Amount: ${order.formattedTotal} (${order.paymentMethod} • ${order.paymentStatus})',
                                    ),
                                    if (order.paymentStatus == 'Pending' &&
                                        order.paymentMethod == 'GCash') ...[
                                      const SizedBox(width: 8),
                                      InkWell(
                                        onTap: () => _showGcashPaymentDialog(
                                          order,
                                          isDark,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withValues(
                                              alpha: 0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            border: Border.all(
                                              color: Colors.blue.withValues(
                                                alpha: 0.3,
                                              ),
                                            ),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.qr_code_2_rounded,
                                                size: 12,
                                                color: Colors.blue,
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                'Scan QR',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.blue,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if (order.orderStatus ==
                                    OrderStatus.pending) ...[
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: () async {
                                        final orderProvider =
                                            Provider.of<OrderProvider>(
                                              context,
                                              listen: false,
                                            );
                                        await orderProvider.confirmOrder(
                                          order.id,
                                        );
                                        if (context.mounted) {
                                          Helpers.showSnackBar(
                                            context,
                                            'Order ${order.id} confirmed successfully!',
                                          );
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primaryColor,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                      ),
                                      child: const Text(
                                        'Confirm Order',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ] else if (order.orderStatus ==
                                    OrderStatus.confirmed) ...[
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: () async {
                                        if (order.requiresDriver) {
                                          final driversList = _allUsers
                                              .where(
                                                (u) =>
                                                    u.role == UserRole.driver,
                                              )
                                              .toList();
                                          if (driversList.isEmpty) {
                                            Helpers.showSnackBar(
                                              context,
                                              'No registered riders available to dispatch.',
                                              isError: true,
                                            );
                                            return;
                                          }
                                          _showAssignDriverDialog(
                                            order,
                                            driversList,
                                            isDark,
                                          );
                                        } else {
                                          final orderProvider =
                                              Provider.of<OrderProvider>(
                                                context,
                                                listen: false,
                                              );
                                          await orderProvider.updateOrderStatus(
                                            orderId: order.id,
                                            newStatus: OrderStatus.completed,
                                          );
                                          if (context.mounted) {
                                            Helpers.showSnackBar(
                                              context,
                                              'Order ${order.id} completed successfully!',
                                            );
                                          }
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            order.paymentMethod ==
                                                'Cash on Delivery'
                                            ? const Color(0xFF8B5CF6)
                                            : const Color(0xFF10B981),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                      ),
                                      child: Text(
                                        order.paymentMethod ==
                                                'Cash on Delivery'
                                            ? 'Assign Rider'
                                            : 'Complete Order',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                                const Divider(height: 20),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    const Text(
                                      'Change Status: ',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ...[
                                      'Pending',
                                      'Confirmed',
                                      if (order.paymentMethod ==
                                          'Cash on Delivery') ...[
                                        'Assigned',
                                        'On Delivery',
                                      ],
                                      'Completed',
                                      'Cancelled',
                                    ].map((st) {
                                      if (st == order.orderStatus.displayName) {
                                        return const SizedBox.shrink();
                                      }
                                      return Container(
                                        margin: const EdgeInsets.only(left: 6),
                                        child: OutlinedButton(
                                          onPressed: () =>
                                              _updateOrderStatus(order.id, st),
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                          ),
                                          child: Text(
                                            st,
                                            style: const TextStyle(
                                              fontSize: 10,
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // TAB 2: DELIVERIES FLEET (GPS & Assignments Monitor)
  // TAB 2: DELIVERIES FLEET (Live GPS & Dispatch Command Center)
  Widget _buildDeliveriesTab(bool isDark) {
    final orderProvider = Provider.of<OrderProvider>(context);
    final allOrders = orderProvider.orders;
    final driversList = _allUsers
        .where((u) => u.role == UserRole.driver)
        .toList();
    final today = DateTime.now();

    // Stats
    final activeOnRouteCount = allOrders
        .where(
          (o) =>
              o.orderStatus == OrderStatus.onDelivery ||
              o.orderStatus == OrderStatus.assigned,
        )
        .length;
    final pendingDispatchCount = allOrders
        .where(
          (o) =>
              o.orderStatus == OrderStatus.pending ||
              o.orderStatus == OrderStatus.confirmed,
        )
        .length;
    final completedCount = allOrders
        .where((o) => o.orderStatus == OrderStatus.completed)
        .length;
    final totalDriversCount = driversList.length;

    // Filter by tab selection
    List<OrderModel> categoryFiltered = allOrders;
    if (_deliveriesFilter == 'Active') {
      categoryFiltered = allOrders
          .where(
            (o) =>
                o.orderStatus == OrderStatus.onDelivery ||
                o.orderStatus == OrderStatus.assigned,
          )
          .toList();
    } else if (_deliveriesFilter == 'Pending') {
      categoryFiltered = allOrders
          .where(
            (o) =>
                o.orderStatus == OrderStatus.pending ||
                o.orderStatus == OrderStatus.confirmed,
          )
          .toList();
    } else if (_deliveriesFilter == 'Completed') {
      categoryFiltered = allOrders
          .where((o) => o.orderStatus == OrderStatus.completed)
          .toList();
    } else if (_deliveriesFilter == 'Today') {
      categoryFiltered = allOrders
          .where(
            (o) =>
                o.createdAt.year == today.year &&
                o.createdAt.month == today.month &&
                o.createdAt.day == today.day,
          )
          .toList();
    }

    // Filter by search query
    final query = _deliveriesSearchController.text.trim().toLowerCase();
    final filteredDeliveries = query.isEmpty
        ? categoryFiltered
        : categoryFiltered.where((o) {
            final id = o.id.toLowerCase();
            final customer = o.customerName.toLowerCase();
            final rider = (o.driverName ?? '').toLowerCase();
            final address = o.deliveryAddress.toLowerCase();
            final water = o.waterType.toLowerCase();
            return id.contains(query) ||
                customer.contains(query) ||
                rider.contains(query) ||
                address.contains(query) ||
                water.contains(query);
          }).toList();

    final cardBgColor = isDark ? AppTheme.darkSurface : Colors.white;
    final titleTextColor = isDark ? Colors.white70 : const Color(0xFF64748B);
    final valueTextColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final borderColor = isDark ? Colors.white10 : const Color(0xFFE2E8F0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fleet & Deliveries Command Center',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Live GPS route tracking, rider dispatches, and delivery telemetry across Ligao City.',
                    style: TextStyle(fontSize: 12, color: titleTextColor),
                  ),
                ],
              ),
              ActionChip(
                avatar: Icon(
                  _mapSatelliteMode
                      ? Icons.satellite_alt_rounded
                      : Icons.map_rounded,
                  size: 16,
                  color: AppTheme.primaryColor,
                ),
                label: Text(
                  _mapSatelliteMode ? 'Satellite Dark' : 'Vector Map',
                ),
                onPressed: () {
                  setState(() {
                    _mapSatelliteMode = !_mapSatelliteMode;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Top KPI Metrics
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 700;
              final crossAxisCount = isNarrow ? 2 : 4;
              return GridView.count(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: isNarrow ? 1.6 : 1.9,
                children: [
                  _buildDeliveryKpiCard(
                    title: 'Active On Route',
                    value: '$activeOnRouteCount Dispatches',
                    icon: Icons.local_shipping_rounded,
                    color: Colors.cyan,
                    cardBg: cardBgColor,
                    borderColor: borderColor,
                    textColor: valueTextColor,
                    subColor: titleTextColor,
                  ),
                  _buildDeliveryKpiCard(
                    title: 'Riders Online',
                    value: '$totalDriversCount Available',
                    icon: Icons.delivery_dining_rounded,
                    color: AppTheme.primaryColor,
                    cardBg: cardBgColor,
                    borderColor: borderColor,
                    textColor: valueTextColor,
                    subColor: titleTextColor,
                  ),
                  _buildDeliveryKpiCard(
                    title: 'Pending Dispatch',
                    value: '$pendingDispatchCount Orders',
                    icon: Icons.pending_actions_rounded,
                    color: Colors.orange,
                    cardBg: cardBgColor,
                    borderColor: borderColor,
                    textColor: valueTextColor,
                    subColor: titleTextColor,
                  ),
                  _buildDeliveryKpiCard(
                    title: 'Delivered Today',
                    value: '$completedCount Completed',
                    icon: Icons.check_circle_rounded,
                    color: Colors.green,
                    cardBg: cardBgColor,
                    borderColor: borderColor,
                    textColor: valueTextColor,
                    subColor: titleTextColor,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Live Route Map Monitor Widget
          Container(
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.radar_rounded,
                          color: AppTheme.primaryColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Live Fleet GPS Route Monitor',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                    if (_selectedDeliveryOrder != null)
                      TextButton.icon(
                        onPressed: () =>
                            setState(() => _selectedDeliveryOrder = null),
                        icon: const Icon(Icons.clear, size: 14),
                        label: const Text(
                          'Clear Selection',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                LiveFleetGpsMapWidget(
                  orders: allOrders,
                  drivers: driversList,
                  selectedOrder: _selectedDeliveryOrder,
                  isDark: isDark,
                  satelliteMode: _mapSatelliteMode,
                  onSelectOrder: (order) {
                    setState(() {
                      _selectedDeliveryOrder = order;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Daily Delivery Assignments & Live Feed
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header & Search
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _deliveriesSearchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText:
                              'Search deliveries by ID, customer, rider, or address...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon:
                              _deliveriesSearchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16),
                                  onPressed: () {
                                    _deliveriesSearchController.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Filter Chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildDeliveryFilterChip(
                      label: 'All Deliveries (${allOrders.length})',
                      value: 'All',
                      icon: Icons.list_alt_rounded,
                    ),
                    _buildDeliveryFilterChip(
                      label: 'On Route ($activeOnRouteCount)',
                      value: 'Active',
                      icon: Icons.local_shipping_rounded,
                    ),
                    _buildDeliveryFilterChip(
                      label: 'Pending ($pendingDispatchCount)',
                      value: 'Pending',
                      icon: Icons.hourglass_top_rounded,
                    ),
                    _buildDeliveryFilterChip(
                      label: 'Completed ($completedCount)',
                      value: 'Completed',
                      icon: Icons.check_circle_outline_rounded,
                    ),
                    _buildDeliveryFilterChip(
                      label: 'Today\'s Feed',
                      value: 'Today',
                      icon: Icons.today_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Deliveries List
                if (filteredDeliveries.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 36.0),
                      child: Column(
                        children: [
                          Icon(
                            Icons.local_shipping_outlined,
                            size: 48,
                            color: const Color(0xFF64748B),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No deliveries match your search or filter.',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: titleTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredDeliveries.length,
                    separatorBuilder: (context, index) =>
                        Divider(color: borderColor, height: 16),
                    itemBuilder: (context, index) {
                      final o = filteredDeliveries[index];
                      final isSelected = _selectedDeliveryOrder?.id == o.id;

                      Color statusColor = o.orderStatus.color;
                      IconData statusIcon = Icons.info_outline;
                      if (o.orderStatus == OrderStatus.pending) {
                        statusIcon = Icons.hourglass_empty_rounded;
                      } else if (o.orderStatus == OrderStatus.confirmed) {
                        statusIcon = Icons.assignment_turned_in_rounded;
                      } else if (o.orderStatus == OrderStatus.assigned) {
                        statusIcon = Icons.assignment_ind_rounded;
                      } else if (o.orderStatus == OrderStatus.onDelivery) {
                        statusIcon = Icons.local_shipping_rounded;
                      } else if (o.orderStatus == OrderStatus.completed) {
                        statusIcon = Icons.check_circle_rounded;
                      }

                      final bool isPending =
                          o.orderStatus == OrderStatus.pending;
                      final bool canAssign =
                          o.orderStatus == OrderStatus.pending ||
                          o.orderStatus == OrderStatus.confirmed ||
                          o.orderStatus == OrderStatus.assigned;
                      final bool canComplete =
                          o.orderStatus == OrderStatus.onDelivery ||
                          o.orderStatus == OrderStatus.assigned;

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primaryColor.withValues(alpha: 0.08)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: isSelected
                              ? Border.all(
                                  color: AppTheme.primaryColor.withValues(
                                    alpha: 0.5,
                                  ),
                                  width: 1.5,
                                )
                              : null,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Status Icon
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                statusIcon,
                                color: statusColor,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),

                            // Main Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        o.id,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: valueTextColor,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: statusColor.withValues(
                                            alpha: 0.15,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          o.orderStatus.displayName,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: statusColor,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '• ${o.waterType} (${o.quantity} jugs)',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: titleTextColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.location_on_outlined,
                                        size: 14,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          '${o.customerName} • ${o.deliveryAddress}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: valueTextColor,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.two_wheeler_rounded,
                                        size: 14,
                                        color: AppTheme.primaryColor,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Rider: ${o.requiresDriver ? (o.driverName ?? "Unassigned") : "Pickup / Walk-in"}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: o.driverName != null
                                              ? AppTheme.primaryColor
                                              : Colors.orange,
                                          fontWeight: o.driverName != null
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Distance: ${o.distance}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: titleTextColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Actions
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Focus on Map Button
                                OutlinedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _selectedDeliveryOrder = o;
                                    });
                                  },
                                  icon: const Icon(
                                    Icons.pin_drop_rounded,
                                    size: 14,
                                  ),
                                  label: Text(
                                    isSelected ? 'Selected' : 'Track',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    side: BorderSide(
                                      color: isSelected
                                          ? AppTheme.primaryColor
                                          : borderColor,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // Dispatch / Complete Button
                                if (isPending)
                                  ElevatedButton(
                                    onPressed: () async {
                                      await orderProvider.confirmOrder(o.id);
                                      if (context.mounted) {
                                        Helpers.showSnackBar(
                                          context,
                                          'Order ${o.id} confirmed!',
                                        );
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryColor,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text(
                                      'Confirm',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.white,
                                      ),
                                    ),
                                  )
                                else if (canAssign)
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      if (driversList.isEmpty) {
                                        Helpers.showSnackBar(
                                          context,
                                          'No registered riders available to dispatch.',
                                          isError: true,
                                        );
                                        return;
                                      }
                                      _showAssignDriverDialog(
                                        o,
                                        driversList,
                                        isDark,
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.person_add_alt_1_rounded,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                    label: Text(
                                      o.driverName != null
                                          ? 'Reassign'
                                          : 'Assign Rider',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.white,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF8B5CF6),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  )
                                else if (canComplete)
                                  ElevatedButton.icon(
                                    onPressed: () async {
                                      await orderProvider.updateOrderStatus(
                                        orderId: o.id,
                                        newStatus: OrderStatus.completed,
                                      );
                                      if (context.mounted) {
                                        Helpers.showSnackBar(
                                          context,
                                          'Order ${o.id} marked as Delivered!',
                                        );
                                      }
                                    },
                                    icon: const Icon(
                                      Icons.check_rounded,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                    label: const Text(
                                      'Delivered',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.white,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF10B981),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color cardBg,
    required Color borderColor,
    required Color textColor,
    required Color subColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: subColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryFilterChip({
    required String label,
    required String value,
    required IconData icon,
  }) {
    final isSelected = _deliveriesFilter == value;
    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 16,
        color: isSelected ? Colors.white : AppTheme.primaryColor,
      ),
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _deliveriesFilter = value;
          });
        }
      },
      selectedColor: AppTheme.primaryColor,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Colors.white : null,
      ),
    );
  }

  void _showAssignDriverDialog(
    OrderModel order,
    List<UserModel> driversList,
    bool isDark,
  ) {
    UserModel selectedDriver = driversList.first;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
              title: const Text('Dispatch Order Delivery'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Assign a rider for Order ${order.id}:'),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<UserModel>(
                    initialValue: selectedDriver,
                    dropdownColor: isDark ? AppTheme.darkSurface : Colors.white,
                    decoration: const InputDecoration(
                      labelText: 'Select Available Rider',
                      prefixIcon: Icon(Icons.delivery_dining_rounded),
                    ),
                    items: driversList.map((d) {
                      return DropdownMenuItem(value: d, child: Text(d.name));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          selectedDriver = val;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final orderProvider = Provider.of<OrderProvider>(
                      context,
                      listen: false,
                    );
                    try {
                      await orderProvider.assignDriver(
                        orderId: order.id,
                        driverId: selectedDriver.id,
                        driverName: selectedDriver.name,
                      );
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        Helpers.showSnackBar(
                          context,
                          'Rider ${selectedDriver.name} assigned successfully!',
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        Helpers.showSnackBar(
                          context,
                          'Dispatch failed: $e',
                          isError: true,
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                  ),
                  child: const Text(
                    'Confirm Dispatch',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showGcashPaymentDialog(OrderModel order, bool isDark) {
    GCashPaymentModal.show(
      context,
      order: order,
      paymentService: _paymentService,
      isDark: isDark,
      role: 'admin',
    );
  }

  // TAB 3: USERS & REGISTERED USER DATABASE
  Widget _buildCustomersTab(bool isDark) {
    if (_allUsers.isEmpty && _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_allUsers.isEmpty) {
      return FutureBuilder<List<UserModel>>(
        future: _apiService.getAdminUsers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final users = snapshot.data ?? [];
          if (users.isEmpty) {
            return const Center(
              child: Text(
                'No registered user accounts found.\nNew sign-ups will automatically appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, height: 1.4),
              ),
            );
          }
          return _buildUsersListPanel(isDark, users, users);
        },
      );
    }

    return _buildUsersListPanel(isDark, _filteredUsers, _allUsers);
  }

  Widget _buildUsersListPanel(
    bool isDark,
    List<UserModel> displayUsers,
    List<UserModel> allUsersSource,
  ) {
    final adminCount =
        allUsersSource.where((u) => u.role == UserRole.admin).length;
    final driverCount =
        allUsersSource.where((u) => u.role == UserRole.driver).length;
    final customerCount =
        allUsersSource.where((u) => u.role == UserRole.customer).length;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search & Filter controls
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => _applyFilters(),
                  decoration: InputDecoration(
                    hintText: 'Search registered user database...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _applyFilters();
                            },
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton.filledTonal(
                tooltip: 'Refresh user database',
                icon: const Icon(Icons.refresh_rounded),
                onPressed: _loadAllDashboardData,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Role Filter Quick Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildRoleFilterChip(
                  label: 'All',
                  roleKey: 'All',
                  count: allUsersSource.length,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 8),
                _buildRoleFilterChip(
                  label: 'Admin',
                  roleKey: 'Admin',
                  count: adminCount,
                  color: const Color(0xFF7C3AED),
                ),
                const SizedBox(width: 8),
                _buildRoleFilterChip(
                  label: 'Driver',
                  roleKey: 'Driver',
                  count: driverCount,
                  color: const Color(0xFFEA580C),
                ),
                const SizedBox(width: 8),
                _buildRoleFilterChip(
                  label: 'Customers',
                  roleKey: 'Customers',
                  count: customerCount,
                  color: const Color(0xFF10B981),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // User list
          Expanded(
            child: displayUsers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 48,
                          color: const Color(0xFF64748B),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No users found matching your filter.',
                          style: TextStyle(
                            color: const Color(0xFF475569),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _selectedRoleFilter = 'All';
                            });
                            _applyFilters();
                          },
                          child: const Text('Reset filters'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: displayUsers.length,
                    itemBuilder: (itemCtx, index) {
                      final cust = displayUsers[index];
                      final initial = cust.name.isNotEmpty
                          ? cust.name[0].toUpperCase()
                          : 'U';

                      // Explicit role label requested by the user: Admin , Driver , Customers
                      final String roleLabel;
                      final Color roleColor;
                      final Color roleBgColor;

                      switch (cust.role) {
                        case UserRole.admin:
                          roleLabel = 'Admin';
                          roleColor = const Color(0xFF7C3AED); // Purple
                          roleBgColor =
                              const Color(0xFF7C3AED).withValues(alpha: 0.10);
                          break;
                        case UserRole.driver:
                          roleLabel = 'Driver';
                          roleColor = const Color(0xFFEA580C); // Orange
                          roleBgColor =
                              const Color(0xFFEA580C).withValues(alpha: 0.10);
                          break;
                        case UserRole.customer:
                          roleLabel = 'Customers';
                          roleColor = const Color(0xFF10B981); // Emerald Green
                          roleBgColor =
                              const Color(0xFF10B981).withValues(alpha: 0.10);
                          break;
                      }

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        elevation: 0.5,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: isDark
                                ? Colors.white10
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          leading: CircleAvatar(
                            backgroundColor:
                                roleColor.withValues(alpha: 0.12),
                            child: Text(
                              initial,
                              style: TextStyle(
                                color: roleColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            cust.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${cust.email} • Role: $roleLabel',
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'ID: ${cust.id}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: roleBgColor,
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                    color: roleColor.withValues(alpha: 0.35),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: roleColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      roleLabel,
                                      style: TextStyle(
                                        color: roleColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleFilterChip({
    required String label,
    required String roleKey,
    required int count,
    required Color color,
  }) {
    final isSelected =
        _selectedRoleFilter.toLowerCase() == roleKey.toLowerCase() ||
        (_selectedRoleFilter == 'All' && roleKey == 'All') ||
        (_selectedRoleFilter.toLowerCase() == 'customer' &&
            roleKey.toLowerCase() == 'customers');

    return InkWell(
      onTap: () {
        setState(() {
          _selectedRoleFilter = roleKey;
        });
        _applyFilters();
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color:
              isSelected ? color.withValues(alpha: 0.14) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.grey.withValues(alpha: 0.35),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : Colors.grey.shade600,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? color : Colors.grey.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper Dialog for Adding or Editing Inventory Items
  void _showAddEditInventoryItemDialog(
    bool isDark, [
    Map<String, dynamic>? itemToEdit,
  ]) {
    final isEditing = itemToEdit != null;
    final nameController = TextEditingController(
      text: isEditing ? (itemToEdit['name'] as String) : '',
    );
    final priceController = TextEditingController(
      text: isEditing ? (itemToEdit['price'] as num).toString() : '',
    );
    final stockController = TextEditingController(
      text: isEditing ? (itemToEdit['stock'] as num).toString() : '',
    );
    final capacityController = TextEditingController(
      text: isEditing ? (itemToEdit['capacity'] as num).toString() : '100',
    );
    final descController = TextEditingController(
      text: isEditing ? (itemToEdit['description'] as String? ?? '') : '',
    );

    String selectedCategory = isEditing
        ? (itemToEdit['category'] as String? ?? 'container')
        : 'container';
    String selectedUnit = isEditing
        ? (itemToEdit['unit'] as String? ?? 'Units')
        : 'Units';
    Color selectedColor = isEditing
        ? (itemToEdit['color'] as Color? ?? Colors.indigo)
        : Colors.indigo;
    IconData selectedIcon = isEditing
        ? (itemToEdit['icon'] as IconData? ?? Icons.local_drink_rounded)
        : Icons.local_drink_rounded;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
              title: Row(
                children: [
                  Icon(
                    isEditing
                        ? Icons.edit_note_rounded
                        : Icons.add_business_rounded,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isEditing
                        ? 'Edit Inventory Item'
                        : 'Add New Inventory Item',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 460,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category Selector
                      Text(
                        'Category',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: selectedCategory,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.category_rounded),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'container',
                            child: Text('🪣 Container & Jug Reserve'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedCategory = val;
                              selectedUnit = 'Units';
                              selectedIcon = Icons.local_drink_rounded;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),

                      // Item Name
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Product / Item Name',
                          hintText:
                              'e.g. 19L Distilled Water or USB Dispenser Pump',
                          prefixIcon: Icon(Icons.label_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Price & Unit Row
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: priceController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Price per Unit (₱)',
                                prefixIcon: Icon(Icons.payments_outlined),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: selectedUnit,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Measurement Unit',
                                prefixIcon: Icon(Icons.straighten_rounded),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'Gallons',
                                  child: Text('Gallons'),
                                ),
                                DropdownMenuItem(
                                  value: 'Jugs',
                                  child: Text('Jugs'),
                                ),
                                DropdownMenuItem(
                                  value: 'Units',
                                  child: Text('Units'),
                                ),
                                DropdownMenuItem(
                                  value: 'Pieces',
                                  child: Text('Pieces'),
                                ),
                                DropdownMenuItem(
                                  value: 'Packs',
                                  child: Text('Packs'),
                                ),
                                DropdownMenuItem(
                                  value: 'Sets',
                                  child: Text('Sets'),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setDialogState(() => selectedUnit = val);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Stock & Capacity Row
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: stockController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: InputDecoration(
                                labelText: isEditing
                                    ? 'Current Stock ($selectedUnit)'
                                    : 'Initial Stock ($selectedUnit)',
                                prefixIcon: const Icon(
                                  Icons.inventory_2_outlined,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: capacityController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: InputDecoration(
                                labelText: 'Max Capacity ($selectedUnit)',
                                prefixIcon: const Icon(Icons.warehouse_rounded),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Description
                      TextField(
                        controller: descController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Description / Specifications (Optional)',
                          prefixIcon: Icon(Icons.description_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Theme Color
                      Text(
                        'Theme Color & Accent',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children:
                            [
                              Colors.blue,
                              Colors.cyan,
                              Colors.teal,
                              Colors.indigo,
                              Colors.deepPurple,
                              Colors.amber,
                              Colors.orange,
                              Colors.green,
                            ].map((c) {
                              final isSelected = selectedColor == c;
                              return GestureDetector(
                                onTap: () {
                                  setDialogState(() {
                                    selectedColor = c;
                                  });
                                },
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: c,
                                    shape: BoxShape.circle,
                                    border: isSelected
                                        ? Border.all(
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black,
                                            width: 3,
                                          )
                                        : null,
                                  ),
                                ),
                              );
                            }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    final price = double.tryParse(priceController.text) ?? 0.0;
                    final stock = double.tryParse(stockController.text) ?? 0.0;
                    final capacity =
                        double.tryParse(capacityController.text) ?? 100.0;
                    final desc = descController.text.trim();

                    if (name.isEmpty ||
                        price < 0 ||
                        stock < 0 ||
                        capacity < stock) {
                      Helpers.showSnackBar(
                        context,
                        'Please enter valid item details. Stock cannot exceed max capacity.',
                        isError: true,
                      );
                      return;
                    }

                    final orderProvider = Provider.of<OrderProvider>(
                      context,
                      listen: false,
                    );
                    if (isEditing) {
                      orderProvider.updateInventoryItem(
                        id: itemToEdit['id'] as String,
                        name: name,
                        category: selectedCategory,
                        unit: selectedUnit,
                        price: price,
                        stock: stock,
                        capacity: capacity,
                        color: selectedColor,
                        icon: selectedIcon,
                        description: desc,
                      );
                      Navigator.of(context).pop();
                      Helpers.showSnackBar(
                        context,
                        'Inventory item "$name" updated successfully!',
                      );
                    } else {
                      orderProvider.addInventoryItem(
                        name: name,
                        category: selectedCategory,
                        unit: selectedUnit,
                        price: price,
                        stock: stock,
                        capacity: capacity,
                        color: selectedColor,
                        icon: selectedIcon,
                        description: desc,
                      );
                      Navigator.of(context).pop();
                      Helpers.showSnackBar(
                        context,
                        'New item "$name" added to inventory!',
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                  ),
                  child: Text(
                    isEditing ? 'Save Changes' : 'Add Item',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Quick Restock Dialog
  void _showRestockDialog(bool isDark, Map<String, dynamic> item) {
    final amountController = TextEditingController(text: '15');
    final String name = item['name'] as String;
    final double stock = (item['stock'] as num).toDouble();
    final double capacity = (item['capacity'] as num).toDouble();
    final String unit = item['unit'] as String? ?? 'Units';
    final Color color = item['color'] as Color? ?? AppTheme.primaryColor;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
              title: Row(
                children: [
                  Icon(Icons.add_shopping_cart_rounded, color: color),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Restock / Refill $name',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Stock: ${stock.toStringAsFixed(1)} / ${capacity.toStringAsFixed(0)} $unit',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Quick Add Amount:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [5.0, 10.0, 15.0, 25.0, 50.0].map((amt) {
                      return ActionChip(
                        label: Text('+$amt $unit'),
                        onPressed: () {
                          setDialogState(() {
                            amountController.text = amt.toStringAsFixed(0);
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Custom Restock Quantity ($unit)',
                      prefixIcon: const Icon(Icons.add_box_rounded),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final amt = double.tryParse(amountController.text) ?? 0.0;
                    if (amt <= 0) {
                      Helpers.showSnackBar(
                        context,
                        'Please enter a valid positive quantity.',
                        isError: true,
                      );
                      return;
                    }
                    final orderProvider = Provider.of<OrderProvider>(
                      context,
                      listen: false,
                    );
                    orderProvider.restockInventoryItem(
                      item['id'] as String,
                      amt,
                    );
                    Navigator.of(context).pop();
                    Helpers.showSnackBar(
                      context,
                      'Restocked +$amt $unit to $name!',
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                  ),
                  child: const Text(
                    'Confirm Restock',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Delete Item Dialog
  void _showDeleteItemDialog(bool isDark, Map<String, dynamic> item) {
    final String name = item['name'] as String;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
          title: const Row(
            children: [
              Icon(Icons.delete_outline_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text('Remove Item from Inventory'),
            ],
          ),
          content: Text(
            'Are you sure you want to remove "$name" from the inventory catalog? This action cannot be undone.',
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.grey.shade700,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final orderProvider = Provider.of<OrderProvider>(
                  context,
                  listen: false,
                );
                orderProvider.deleteInventoryItem(item['id'] as String);
                Navigator.of(context).pop();
                Helpers.showSnackBar(
                  context,
                  'Removed "$name" from inventory.',
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  // TAB 4: INVENTORY & RESERVES (Comprehensive Catalog, Full CRUD, Filters & Stocks)
  Widget _buildInventoryTab(bool isDark) {
    final orderProvider = Provider.of<OrderProvider>(context);
    final cardBgColor = isDark ? AppTheme.darkSurface : Colors.white;
    final titleTextColor = isDark ? Colors.white70 : const Color(0xFF64748B);
    final valueTextColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final borderColor = isDark ? Colors.white10 : const Color(0xFFE2E8F0);

    final allItems = orderProvider.inventoryItems
        .where((i) => i['category'] == 'container')
        .toList();

    // Filter by search query
    final query = _inventorySearchController.text.trim().toLowerCase();
    final filteredItems = query.isEmpty
        ? allItems
        : allItems.where((i) {
            final name = (i['name'] as String? ?? '').toLowerCase();
            final desc = (i['description'] as String? ?? '').toLowerCase();
            return name.contains(query) || desc.contains(query);
          }).toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Inventory & Stock Operations',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Manage container reserves, gallon bottles, and live stock levels.',
                    style: TextStyle(fontSize: 12, color: titleTextColor),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddEditInventoryItemDialog(isDark),
                icon: const Icon(
                  Icons.add_rounded,
                  size: 18,
                  color: Colors.white,
                ),
                label: const Text(
                  'Add Product / Item',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: TextField(
              controller: _inventorySearchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search containers & jugs by name or description...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _inventorySearchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _inventorySearchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Inventory Grid Items
          if (filteredItems.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: cardBgColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 48,
                    color: const Color(0xFF64748B),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No inventory items match your search or filter.',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: titleTextColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => _showAddEditInventoryItemDialog(isDark),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add First Item'),
                  ),
                ],
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredItems.length,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 420,
                mainAxisExtent: 220,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemBuilder: (context, index) {
                final prod = filteredItems[index];
                final String name = prod['name'] as String;
                final double stock = (prod['stock'] as num).toDouble();
                final double capacity = (prod['capacity'] as num).toDouble();
                final double price = (prod['price'] as num).toDouble();
                final String unit = prod['unit'] as String? ?? 'Units';
                final String description = prod['description'] as String? ?? '';
                final Color color =
                    prod['color'] as Color? ?? AppTheme.primaryColor;
                final String? imagePath = prod['image'] as String?;
                final IconData icon =
                    prod['icon'] as IconData? ?? Icons.inventory_2_rounded;

                final ratio = capacity > 0
                    ? (stock / capacity).clamp(0.0, 1.0)
                    : 0.0;
                final bool isOutOfStock = stock <= 0;
                final bool isLowStock = !isOutOfStock && ratio < 0.3;

                String statusLabel = 'In Stock';
                Color statusColor = Colors.green;
                if (isOutOfStock) {
                  statusLabel = 'Out of Stock';
                  statusColor = Colors.red;
                } else if (isLowStock) {
                  statusLabel = 'Low Stock';
                  statusColor = Colors.orange;
                }

                String categoryBadgeText = '🪣 Container';
                if (description.isNotEmpty) {
                  categoryBadgeText = '$categoryBadgeText • $description';
                }

                return Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: cardBgColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isLowStock
                          ? Colors.orange.withValues(alpha: 0.4)
                          : (isOutOfStock
                                ? Colors.red.withValues(alpha: 0.4)
                                : borderColor),
                      width: (isLowStock || isOutOfStock) ? 1.5 : 1.0,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: imagePath != null
                                      ? Image.asset(
                                          imagePath,
                                          fit: BoxFit.contain,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  Icon(
                                                    icon,
                                                    color: color,
                                                    size: 20,
                                                  ),
                                        )
                                      : Icon(icon, color: color, size: 20),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: valueTextColor,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        categoryBadgeText,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: titleTextColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Stock Available Text
                      Text(
                        '${stock.toStringAsFixed(stock % 1 == 0 ? 0 : 1)} / ${capacity.toStringAsFixed(0)} $unit Available',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: valueTextColor,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Progress Indicator
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 6,
                          backgroundColor: isDark
                              ? Colors.white10
                              : Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            statusColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Price and actions row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '₱${price.toStringAsFixed(2)} / $unit',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.cyanAccent
                                  : AppTheme.primaryColor,
                            ),
                          ),
                          Row(
                            children: [
                              // Quick Restock Button
                              IconButton(
                                tooltip: 'Restock',
                                icon: Icon(
                                  Icons.add_shopping_cart_rounded,
                                  size: 18,
                                  color: color,
                                ),
                                visualDensity: VisualDensity.compact,
                                onPressed: () =>
                                    _showRestockDialog(isDark, prod),
                              ),
                              // Edit Button
                              IconButton(
                                tooltip: 'Edit Details',
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                visualDensity: VisualDensity.compact,
                                onPressed: () =>
                                    _showAddEditInventoryItemDialog(
                                      isDark,
                                      prod,
                                    ),
                              ),
                              // Delete Button
                              IconButton(
                                tooltip: 'Delete Item',
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 18,
                                  color: Colors.red,
                                ),
                                visualDensity: VisualDensity.compact,
                                onPressed: () =>
                                    _showDeleteItemDialog(isDark, prod),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // TAB 5: PAYMENTS TRANSACTIONS (Realtime live transaction monitor)
  Widget _buildPaymentsTab(bool isDark) {
    final orderProvider = Provider.of<OrderProvider>(context);
    final allOrders = orderProvider.orders;

    // Financial Metrics
    double totalPaidRevenue = 0.0;
    double totalGcashRevenue = 0.0;
    int gcashPaidCount = 0;
    double totalCodRevenue = 0.0;
    int codPaidCount = 0;
    int pendingCount = 0;

    for (var o in allOrders) {
      if (o.paymentStatus == 'Paid') {
        totalPaidRevenue += o.totalAmount;
        if (o.paymentMethod.toLowerCase().contains('gcash')) {
          totalGcashRevenue += o.totalAmount;
          gcashPaidCount++;
        } else {
          totalCodRevenue += o.totalAmount;
          codPaidCount++;
        }
      } else {
        pendingCount++;
      }
    }

    // Filter & Search logic
    final query = _paymentsSearchController.text.trim().toLowerCase();
    final filtered = allOrders.where((o) {
      final matchesQuery = query.isEmpty ||
          o.id.toLowerCase().contains(query) ||
          o.txnId.toLowerCase().contains(query) ||
          o.customerName.toLowerCase().contains(query) ||
          o.customerPhone.toLowerCase().contains(query);

      bool matchesFilter = true;
      if (_paymentsFilter == 'GCash') {
        matchesFilter = o.paymentMethod.toLowerCase().contains('gcash');
      } else if (_paymentsFilter == 'Cash on Delivery') {
        matchesFilter = !o.paymentMethod.toLowerCase().contains('gcash');
      } else if (_paymentsFilter == 'Paid') {
        matchesFilter = o.paymentStatus == 'Paid';
      } else if (_paymentsFilter == 'Pending') {
        matchesFilter = o.paymentStatus != 'Paid';
      }

      return matchesQuery && matchesFilter;
    }).toList();

    final cardBg = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? const Color(0xFF64748B) : const Color(0xFF64748B);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Live Indicator & Sync Action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Real-Time Payment Transactions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Live Stream Active',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Instant synchronization for GCash and Cash transactions across customer & rider apps.',
                    style: TextStyle(fontSize: 12, color: subtextColor),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  await orderProvider.fetchSupabaseOrders(silent: false);
                  if (!mounted) return;
                  Helpers.showSnackBar(context, 'Transactions synced with database.');
                },
                icon: const Icon(Icons.sync_rounded, size: 16),
                label: const Text('Refresh Feed'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  side: const BorderSide(color: AppTheme.primaryColor),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Summary Stats Cards
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total Revenue (Paid)', style: TextStyle(fontSize: 11, color: subtextColor)),
                      const SizedBox(height: 4),
                      Text(
                        '₱${totalPaidRevenue.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF007DFE),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text('GCash Collected', style: TextStyle(fontSize: 11, color: subtextColor)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₱${totalGcashRevenue.toStringAsFixed(2)} ($gcashPaidCount)',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF007DFE)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('COD Collected', style: TextStyle(fontSize: 11, color: subtextColor)),
                      const SizedBox(height: 4),
                      Text(
                        '₱${totalCodRevenue.toStringAsFixed(2)} ($codPaidCount)',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: titleColor),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pending Settlement', style: TextStyle(fontSize: 11, color: subtextColor)),
                      const SizedBox(height: 4),
                      Text(
                        '$pendingCount orders',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Search and Filter Bar
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: borderColor),
                  ),
                  child: TextField(
                    controller: _paymentsSearchController,
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(fontSize: 12, color: titleColor),
                    decoration: InputDecoration(
                      hintText: 'Search by Txn Ref, Order #, or Customer...',
                      hintStyle: TextStyle(fontSize: 12, color: const Color(0xFF64748B)),
                      prefixIcon: const Icon(Icons.search, size: 18),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 3,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['All', 'GCash', 'Cash on Delivery', 'Paid', 'Pending'].map((filter) {
                      final isSel = _paymentsFilter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(filter),
                          selected: isSel,
                          selectedColor: AppTheme.primaryColor,
                          labelStyle: TextStyle(
                            color: isSel ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                          onSelected: (val) {
                            setState(() {
                              _paymentsFilter = filter;
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Transactions List View
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 48, color: const Color(0xFF64748B)),
                        const SizedBox(height: 12),
                        Text(
                          'No payment transactions match this filter.',
                          style: TextStyle(fontWeight: FontWeight.bold, color: titleColor),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (itemCtx, index) {
                      final pay = filtered[index];
                      final isSuccess = pay.paymentStatus == 'Paid';
                      final isGcash = pay.paymentMethod.toLowerCase().contains('gcash');
                      final statusColor = isSuccess ? Colors.green : Colors.amber.shade700;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isGcash && isSuccess
                                ? const Color(0xFF007DFE).withValues(alpha: 0.3)
                                : borderColor,
                            width: isGcash && isSuccess ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Method Avatar
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: isGcash
                                    ? const Color(0xFF007DFE).withValues(alpha: 0.12)
                                    : Colors.green.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Icon(
                                  isGcash ? Icons.account_balance_wallet_rounded : Icons.payments_rounded,
                                  color: isGcash ? const Color(0xFF007DFE) : Colors.green,
                                  size: 22,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),

                            // Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        pay.txnId,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: titleColor,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isGcash
                                              ? const Color(0xFF007DFE).withValues(alpha: 0.12)
                                              : Colors.grey.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          pay.paymentMethod,
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: isGcash ? const Color(0xFF007DFE) : subtextColor,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '• Order ${pay.id}',
                                        style: TextStyle(fontSize: 11, color: subtextColor),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${pay.customerName} (${pay.customerPhone}) • ${pay.itemsSummary}',
                                    style: TextStyle(fontSize: 12, color: titleColor, fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Placed: ${pay.createdAt.toString().split('.')[0]}',
                                    style: TextStyle(fontSize: 10, color: subtextColor),
                                  ),
                                ],
                              ),
                            ),

                            // Trailing Amount & Status
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  pay.formattedTotal,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                    color: isGcash ? const Color(0xFF007DFE) : titleColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isSuccess ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
                                            size: 10,
                                            color: statusColor,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            pay.paymentStatus,
                                            style: TextStyle(
                                              color: statusColor,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (!isSuccess) ...[
                                      const SizedBox(width: 6),
                                      InkWell(
                                        onTap: () async {
                                          await orderProvider.markOrderAsPaid(pay.id);
                                          if (!mounted) return;
                                          Helpers.showSnackBar(
                                            context,
                                            'Order ${pay.id} confirmed as Paid in database.',
                                          );
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Colors.green,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text(
                                            'Mark Paid',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // TAB 6: ANALYTICS & REPORTS (Realtime Income and Sales reports)
  Widget _buildReportsTab(bool isDark) {
    final orderProvider = Provider.of<OrderProvider>(context);
    final allOrders = orderProvider.orders;

    // 1. Filter orders matching report criteria
    final reportOrders = allOrders.where((o) {
      // Only count completed or paid orders as income
      if (o.orderStatus != OrderStatus.completed && o.paymentStatus != 'Paid') {
        return false;
      }

      final date = o.createdAt;
      switch (_reportInterval) {
        case 'Daily':
          return date.year == _selectedReportDate.year &&
              date.month == _selectedReportDate.month &&
              date.day == _selectedReportDate.day;
        case 'Weekly':
          // Start of selected date's week (assuming Sunday is start of week)
          final startOfWeek = DateTime(
            _selectedReportDate.year,
            _selectedReportDate.month,
            _selectedReportDate.day,
          ).subtract(Duration(days: _selectedReportDate.weekday % 7));
          final endOfWeek = startOfWeek.add(const Duration(days: 7));
          return date.isAfter(
                startOfWeek.subtract(const Duration(seconds: 1)),
              ) &&
              date.isBefore(endOfWeek);
        case 'Monthly':
          return date.year == _selectedReportDate.year &&
              date.month == _selectedReportDate.month;
        case 'Annually':
          return date.year == _selectedReportDate.year;
        default:
          return false;
      }
    }).toList();

    // 2. Calculations
    double totalRevenue = 0;
    int purifiedJugQty = 0;
    int alkalineJugQty = 0;
    for (var o in reportOrders) {
      totalRevenue += o.totalAmount;
      if (o.waterType.toLowerCase().contains('purified')) {
        purifiedJugQty += o.quantity;
      } else {
        alkalineJugQty += o.quantity;
      }
    }
    double averageOrderValue = reportOrders.isEmpty
        ? 0
        : totalRevenue / reportOrders.length;
    String popularType = (purifiedJugQty >= alkalineJugQty)
        ? '19L Purified'
        : '19L Alkaline';

    // 3. Group income for Chart Visualizer
    final List<Map<String, dynamic>> chartData = [];
    if (_reportInterval == 'Daily') {
      // Group by 6-hour slots
      final slots = [
        {
          'label': '12AM - 6AM',
          'hours': [0, 1, 2, 3, 4, 5],
          'amount': 0.0,
        },
        {
          'label': '6AM - 12PM',
          'hours': [6, 7, 8, 9, 10, 11],
          'amount': 0.0,
        },
        {
          'label': '12PM - 6PM',
          'hours': [12, 13, 14, 15, 16, 17],
          'amount': 0.0,
        },
        {
          'label': '6PM - 12AM',
          'hours': [18, 19, 20, 21, 22, 23],
          'amount': 0.0,
        },
      ];
      for (var o in reportOrders) {
        final hr = o.createdAt.hour;
        for (var slot in slots) {
          if ((slot['hours'] as List<int>).contains(hr)) {
            slot['amount'] = (slot['amount'] as double) + o.totalAmount;
          }
        }
      }
      chartData.addAll(slots);
    } else if (_reportInterval == 'Weekly') {
      // Group by Day of the Week
      final days = [
        {'label': 'Sun', 'weekday': 7, 'amount': 0.0},
        {'label': 'Mon', 'weekday': 1, 'amount': 0.0},
        {'label': 'Tue', 'weekday': 2, 'amount': 0.0},
        {'label': 'Wed', 'weekday': 3, 'amount': 0.0},
        {'label': 'Thu', 'weekday': 4, 'amount': 0.0},
        {'label': 'Fri', 'weekday': 5, 'amount': 0.0},
        {'label': 'Sat', 'weekday': 6, 'amount': 0.0},
      ];
      for (var o in reportOrders) {
        final wd = o.createdAt.weekday;
        for (var day in days) {
          if (day['weekday'] == wd) {
            day['amount'] = (day['amount'] as double) + o.totalAmount;
          }
        }
      }
      chartData.addAll(days);
    } else if (_reportInterval == 'Monthly') {
      // Group by Weeks of Month
      final weeks = [
        {
          'label': 'Week 1',
          'range': [1, 2, 3, 4, 5, 6, 7],
          'amount': 0.0,
        },
        {
          'label': 'Week 2',
          'range': [8, 9, 10, 11, 12, 13, 14],
          'amount': 0.0,
        },
        {
          'label': 'Week 3',
          'range': [15, 16, 17, 18, 19, 20, 21],
          'amount': 0.0,
        },
        {
          'label': 'Week 4',
          'range': [22, 23, 24, 25, 26, 27, 28],
          'amount': 0.0,
        },
        {
          'label': 'Week 5',
          'range': [29, 30, 31],
          'amount': 0.0,
        },
      ];
      for (var o in reportOrders) {
        final d = o.createdAt.day;
        for (var week in weeks) {
          if ((week['range'] as List<int>).contains(d)) {
            week['amount'] = (week['amount'] as double) + o.totalAmount;
          }
        }
      }
      chartData.addAll(weeks);
    } else {
      // Group by Quarter of the Year
      final quarters = [
        {
          'label': 'Q1 (Jan-Mar)',
          'months': [1, 2, 3],
          'amount': 0.0,
        },
        {
          'label': 'Q2 (Apr-Jun)',
          'months': [4, 5, 6],
          'amount': 0.0,
        },
        {
          'label': 'Q3 (Jul-Sep)',
          'months': [7, 8, 9],
          'amount': 0.0,
        },
        {
          'label': 'Q4 (Oct-Dec)',
          'months': [10, 11, 12],
          'amount': 0.0,
        },
      ];
      for (var o in reportOrders) {
        final m = o.createdAt.month;
        for (var q in quarters) {
          if ((q['months'] as List<int>).contains(m)) {
            q['amount'] = (q['amount'] as double) + o.totalAmount;
          }
        }
      }
      chartData.addAll(quarters);
    }

    // Maximum value in chart for percentage calculation
    double maxVal = 0.0;
    for (var data in chartData) {
      if ((data['amount'] as double) > maxVal) {
        maxVal = data['amount'] as double;
      }
    }
    if (maxVal == 0.0) maxVal = 100.0; // avoid divide by zero

    String reportFormattedDate = '';
    if (_reportInterval == 'Daily') {
      reportFormattedDate =
          '${_selectedReportDate.month}/${_selectedReportDate.day}/${_selectedReportDate.year}';
    } else if (_reportInterval == 'Weekly') {
      final start = _selectedReportDate.subtract(
        Duration(days: _selectedReportDate.weekday % 7),
      );
      final end = start.add(const Duration(days: 6));
      reportFormattedDate =
          'Week of ${start.month}/${start.day} to ${end.month}/${end.day}';
    } else if (_reportInterval == 'Monthly') {
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      reportFormattedDate =
          '${months[_selectedReportDate.month - 1]} ${_selectedReportDate.year}';
    } else {
      reportFormattedDate = 'Year ${_selectedReportDate.year}';
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final int metricCrossCount = screenWidth < 600 ? 1 : 2;
    final double metricAspectRatio = screenWidth < 600 ? 3.0 : 2.2;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Title and Date Picker
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Realtime Financial Reports',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Viewing income generated for $reportFormattedDate',
                      style: TextStyle(
                        color: const Color(0xFF475569),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedReportDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setState(() {
                      _selectedReportDate = date;
                    });
                  }
                },
                icon: const Icon(Icons.calendar_today_rounded, size: 14),
                label: const Text('Change Date'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Interval Tab Selector
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: ['Daily', 'Weekly', 'Monthly', 'Annually'].map((
                interval,
              ) {
                final isSel = _reportInterval == interval;
                return Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _reportInterval = interval),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSel
                            ? AppTheme.primaryColor
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          interval == 'Annually' ? 'Annually' : interval,
                          style: TextStyle(
                            color: isSel
                                ? Colors.white
                                : (isDark
                                      ? const Color(0xFF64748B)
                                      : Colors.grey.shade700),
                            fontWeight: isSel
                                ? FontWeight.bold
                                : FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),

          // Summary Metrics Cards Grid
          GridView.count(
            crossAxisCount: metricCrossCount,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: metricAspectRatio,
            children: [
              _buildReportMetricCard(
                'Total Revenue',
                '₱${totalRevenue.toStringAsFixed(2)}',
                Icons.payments_rounded,
                Colors.green,
                isDark,
              ),
              _buildReportMetricCard(
                'Completed Orders',
                '${reportOrders.length}',
                Icons.check_circle_rounded,
                Colors.blue,
                isDark,
              ),
              _buildReportMetricCard(
                'Average Order Value',
                '₱${averageOrderValue.toStringAsFixed(2)}',
                Icons.calculate_rounded,
                Colors.orange,
                isDark,
              ),
              _buildReportMetricCard(
                'Popular Water',
                popularType,
                Icons.local_drink_rounded,
                Colors.cyan,
                isDark,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Visual Chart Cards
          Card(
            color: isDark ? AppTheme.darkSurface : Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Income Distribution & Breakdown',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  ...chartData.map((data) {
                    final amount = data['amount'] as double;
                    final pct = amount / maxVal;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 90,
                            child: Text(
                              data['label'] as String,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: pct,
                                minHeight: 14,
                                backgroundColor: isDark
                                    ? Colors.white10
                                    : Colors.grey.shade100,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppTheme.primaryColor,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '₱${amount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Transactions Breakdown List
          Card(
            color: isDark ? AppTheme.darkSurface : Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Contributing Orders ($reportFormattedDate)',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  reportOrders.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24.0),
                          child: Center(
                            child: Text(
                              'No transactions recorded for this period.',
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: reportOrders.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final o = reportOrders[index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundColor: AppTheme.primaryColor
                                    .withValues(alpha: 0.08),
                                child: const Icon(
                                  Icons.receipt_long_rounded,
                                  color: AppTheme.primaryColor,
                                  size: 18,
                                ),
                              ),
                              title: Text(
                                '${o.id} • ${o.customerName}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              subtitle: Text(
                                '${o.itemsSummary} • ${o.paymentMethod}\nPlaced at: ${o.createdAt.toString().split('.')[0]}',
                                style: const TextStyle(fontSize: 10),
                              ),
                              trailing: Text(
                                o.formattedTotal,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Export & Print Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isActionLoading
                      ? null
                      : () async {
                          if (reportOrders.isEmpty) {
                            Helpers.showSnackBar(
                              context,
                              'No orders available to export.',
                              isError: true,
                            );
                            return;
                          }
                          setState(() => _isActionLoading = true);
                          try {
                            await ReportService.exportCSV(
                              orders: reportOrders,
                              interval: _reportInterval,
                              formattedDate: reportFormattedDate,
                            );
                            if (mounted) {
                              Helpers.showSnackBar(
                                context,
                                'CSV report export triggered successfully!',
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              Helpers.showSnackBar(
                                context,
                                'Failed to export CSV: $e',
                                isError: true,
                              );
                            }
                          } finally {
                            if (mounted) {
                              setState(() => _isActionLoading = false);
                            }
                          }
                        },
                  icon: const Icon(Icons.file_download_rounded, size: 16),
                  label: const Text(
                    'Export CSV',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isActionLoading
                      ? null
                      : () async {
                          if (reportOrders.isEmpty) {
                            Helpers.showSnackBar(
                              context,
                              'No orders available to print.',
                              isError: true,
                            );
                            return;
                          }
                          setState(() => _isActionLoading = true);
                          try {
                            await ReportService.printPDF(
                              orders: reportOrders,
                              interval: _reportInterval,
                              formattedDate: reportFormattedDate,
                            );
                          } catch (e) {
                            if (mounted) {
                              Helpers.showSnackBar(
                                context,
                                'Failed to print report: $e',
                                isError: true,
                              );
                            }
                          } finally {
                            if (mounted) {
                              setState(() => _isActionLoading = false);
                            }
                          }
                        },
                  icon: const Icon(Icons.print_rounded, size: 16),
                  label: const Text(
                    'Print Report',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isActionLoading
                      ? null
                      : () async {
                          if (reportOrders.isEmpty) {
                            Helpers.showSnackBar(
                              context,
                              'No orders available to download.',
                              isError: true,
                            );
                            return;
                          }
                          setState(() => _isActionLoading = true);
                          try {
                            await ReportService.downloadPDF(
                              orders: reportOrders,
                              interval: _reportInterval,
                              formattedDate: reportFormattedDate,
                            );
                            if (mounted) {
                              Helpers.showSnackBar(
                                context,
                                'PDF report download triggered successfully!',
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              Helpers.showSnackBar(
                                context,
                                'Failed to download PDF: $e',
                                isError: true,
                              );
                            }
                          } finally {
                            if (mounted) {
                              setState(() => _isActionLoading = false);
                            }
                          }
                        },
                  icon: const Icon(
                    Icons.download_for_offline_rounded,
                    size: 16,
                  ),
                  label: const Text(
                    'Download PDF',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReportMetricCard(
    String title,
    String value,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: const Color(0xFF475569),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
        ],
      ),
    );
  }

  // TAB 7: AI CHAT SUPPORT (Full page chat)
  Widget _buildSupportTab(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: const [
                  CircleAvatar(
                    backgroundColor: AppTheme.primaryColor,
                    child: Icon(Icons.psychology_rounded, color: Colors.white),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'AquaBot Dispatch Agent',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: _chatScrollController,
                padding: const EdgeInsets.all(16.0),
                itemCount: _supportMessages.length,
                itemBuilder: (context, index) {
                  final msg = _supportMessages[index];
                  final isBot = msg['sender'] == 'AquaBot';
                  return Align(
                    alignment: isBot
                        ? Alignment.centerLeft
                        : Alignment.centerRight,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isBot
                            ? const Color(0xFFF1F9FB)
                            : AppTheme.primaryColor,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(12),
                          topRight: const Radius.circular(12),
                          bottomLeft: isBot
                              ? Radius.zero
                              : const Radius.circular(12),
                          bottomRight: isBot
                              ? const Radius.circular(12)
                              : Radius.zero,
                        ),
                        border: isBot
                            ? Border.all(color: const Color(0xFFE2F0F3))
                            : null,
                      ),
                      child: Text(
                        msg['message'] as String,
                        style: TextStyle(
                          color: isBot ? const Color(0xFF1F2937) : Colors.white,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _supportInputController,
                      onSubmitted: _sendSupportMessage,
                      decoration: const InputDecoration(
                        hintText: 'Type your support request...',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FloatingActionButton(
                    onPressed: () =>
                        _sendSupportMessage(_supportInputController.text),
                    backgroundColor: AppTheme.primaryColor,
                    mini: true,
                    child: const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 18,
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

  // TAB 8: USERS TAB (Was user directory role editor)
  Widget _buildUsersTab(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => _applyFilters(),
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search by name or email...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    filled: true,
                    fillColor: isDark ? AppTheme.darkSurface : Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark
                            ? Colors.white10
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark
                            ? Colors.white10
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedRoleFilter,
                    onChanged: (String? val) {
                      if (val != null) {
                        setState(() {
                          _selectedRoleFilter = val;
                        });
                        _applyFilters();
                      }
                    },
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.grey.shade800,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'All', child: Text('All Roles')),
                      DropdownMenuItem(
                        value: 'Admin',
                        child: Text('Administrators'),
                      ),
                      DropdownMenuItem(value: 'Driver', child: Text('Drivers')),
                      DropdownMenuItem(
                        value: 'Customer',
                        child: Text('Customers'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _filteredUsers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 48,
                          color: const Color(0xFF475569),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No accounts match your criteria',
                          style: TextStyle(color: const Color(0xFF475569)),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = _filteredUsers[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkSurface : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.03)
                                : const Color(0xFFE2E8F0),
                            width: 1.0,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor: _getRoleColor(
                              user.role,
                            ).withValues(alpha: 0.12),
                            child: Icon(
                              _getRoleIcon(user.role),
                              color: _getRoleColor(user.role),
                              size: 16,
                            ),
                          ),
                          title: Text(
                            user.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            user.email,
                            style: TextStyle(
                              color: const Color(0xFF475569),
                              fontSize: 12,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getRoleColor(
                                    user.role,
                                  ).withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: _getRoleColor(
                                      user.role,
                                    ).withValues(alpha: 0.2),
                                    width: 1.0,
                                  ),
                                ),
                                child: Text(
                                  user.roleDisplayName,
                                  style: TextStyle(
                                    color: _getRoleColor(user.role),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _isActionLoading
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : PopupMenuButton<UserRole>(
                                      icon: const Icon(
                                        Icons.more_vert_rounded,
                                        size: 20,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      onSelected: (role) =>
                                          _handleUpdateRole(user, role),
                                      itemBuilder: (context) {
                                        return UserRole.values.map((role) {
                                          return PopupMenuItem<UserRole>(
                                            value: role,
                                            child: Text(
                                              'Set to ${Helpers.capitalize(role.name)}',
                                              style: const TextStyle(
                                                fontSize: 13,
                                              ),
                                            ),
                                          );
                                        }).toList();
                                      },
                                    ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return AppTheme.primaryColor;
      case UserRole.driver:
        return AppTheme.secondaryColor;
      case UserRole.customer:
        return const Color(0xFF10B981);
    }
  }

  IconData _getRoleIcon(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Icons.admin_panel_settings_rounded;
      case UserRole.driver:
        return Icons.local_shipping_rounded;
      case UserRole.customer:
        return Icons.person_rounded;
    }
  }

  // TAB 9: SETTINGS
  Widget _buildSettingsTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Global Application Configuration',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(
                      Icons.cloud_done_rounded,
                      color: AppTheme.primaryColor,
                      size: 22,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Supabase Integration',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSettingRow(
                  'Connection Status',
                  _apiService.isSupabaseConfigured
                      ? 'Connected (Active Database)'
                      : 'Not Configured (Running Fallback Mock Mode)',
                  isSuccess: _apiService.isSupabaseConfigured,
                ),
                const Divider(height: 24, color: Colors.white10),
                _buildSettingRow('Database Endpoint', AppConstants.supabaseUrl),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(
                      Icons.settings_suggest_rounded,
                      color: AppTheme.accentColor,
                      size: 22,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'UI & Control Settings',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Developer Diagnostic Mode',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Show warning popups and verbose console output for backend services.',
                    style: TextStyle(fontSize: 11),
                  ),
                  trailing: Switch(
                    value: true,
                    onChanged: (val) {
                      Helpers.showSnackBar(
                        context,
                        'Developer Diagnostic Mode Toggled!',
                      );
                    },
                    activeThumbColor: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingRow(String label, String value, {bool? isSuccess}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: const Color(0xFF475569),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isSuccess == null
                  ? null
                  : (isSuccess ? Colors.green : Colors.amber.shade700),
            ),
          ),
        ),
      ],
    );
  }
}

class _SidebarItemTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? textColor;

  const _SidebarItemTile({
    required this.icon,
    required this.title,
    required this.isSelected,
    required this.onTap,
    this.textColor,
  });

  @override
  State<_SidebarItemTile> createState() => _SidebarItemTileState();
}

class _SidebarItemTileState extends State<_SidebarItemTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final bool active = widget.isSelected;
    final bool highlighted = active || _isHovered;

    Color backgroundColor;
    Color contentColor;
    if (active) {
      backgroundColor = AppTheme.navyColor;
      contentColor = Colors.white;
    } else if (_isHovered) {
      backgroundColor = const Color(0xFFEFF6FF);
      contentColor = widget.textColor ?? AppTheme.navyColor;
    } else {
      backgroundColor = Colors.transparent;
      contentColor = widget.textColor ?? const Color(0xFF334155);
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 2.0),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: ListTile(
          onTap: widget.onTap,
          dense: true,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          leading: Icon(widget.icon, size: 20, color: contentColor),
          title: Text(
            widget.title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: highlighted ? FontWeight.w800 : FontWeight.w500,
              color: contentColor,
            ),
          ),
        ),
      ),
    );
  }
}

class PulsingBorder extends StatefulWidget {
  final Widget child;
  final Color color;
  final bool active;
  final EdgeInsetsGeometry? margin;

  const PulsingBorder({
    super.key,
    required this.child,
    required this.color,
    this.active = true,
    this.margin,
  });

  @override
  State<PulsingBorder> createState() => _PulsingBorderState();
}

class _PulsingBorderState extends State<PulsingBorder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.1, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          margin: widget.margin,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.3 * _animation.value),
                blurRadius: 8 * _animation.value,
                spreadRadius: 2 * _animation.value,
              ),
            ],
          ),
          child: widget.child,
        );
      },
    );
  }
}
