import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/helpers.dart';
import '../../../models/order_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/order_provider.dart';
import '../../../services/api_service.dart';
import '../../../services/payment_service.dart';
import '../../../services/ai_support_service.dart';
import '../../../widgets/water_widgets.dart';
import '../../../widgets/google_map_widget.dart';
import '../../../widgets/gcash_payment_modal.dart';
import 'customer_styles.dart';

class CustomerDashboard extends StatefulWidget {
  const CustomerDashboard({super.key});

  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  final ApiService _apiService = ApiService();
  final PaymentService _paymentService = PaymentService();
  bool _isLoading = true;
  int _selectedTab = 0;
  int _activeSidebarMenu = 0;

  // Order Water Form States
  String _selectedWaterType = '19L Purified Water';
  int _orderQuantity = 2;
  final TextEditingController _orderAddressController = TextEditingController(
    text: '123 Rizal Ave, Brgy. San Isidro',
  );
  String _selectedPaymentMethod = 'Cash on Delivery';

  // Support Chat States
  final List<Map<String, dynamic>> _chatMessages = [
    {
      'sender': 'AquaBot',
      'message': "Hello! I'm AquaBot 💧 How can I help you today?",
    },
  ];
  final TextEditingController _chatInputController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  bool _isChatLoading = false;

  // Settings profile fields
  late TextEditingController _profileNameController;
  late TextEditingController _profilePhoneController;
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _profileNameController = TextEditingController(text: 'Customer User');
    _profilePhoneController = TextEditingController(text: '+63 912 345 6789');
    
    // Initialize selected water type dynamically from OrderProvider catalog
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      if (orderProvider.waterProducts.isNotEmpty) {
        setState(() {
          _selectedWaterType = orderProvider.waterProducts.first['name'] as String;
        });
      }
    });

    _loadDashboardData();
  }

  @override
  void dispose() {
    _orderAddressController.dispose();
    _chatInputController.dispose();
    _chatScrollController.dispose();
    _profileNameController.dispose();
    _profilePhoneController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _apiService.getCustomerDashboardData();
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(
          context,
          'Failed to load statistics.',
          isError: true,
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _submitWaterOrder() async {
    if (_orderAddressController.text.trim().isEmpty) {
      Helpers.showSnackBar(
        context,
        'Please enter a delivery address.',
        isError: true,
      );
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final user = auth.currentUser;

    final match = orderProvider.waterProducts.firstWhere(
      (p) => p['name'] == _selectedWaterType,
      orElse: () => orderProvider.waterProducts.first,
    );
    final pricePerJug = match['price'] as double;
    final waterTypeName = match['name'] as String;

    final newOrder = await orderProvider.placeOrder(
      customerId: user?.id ?? '',
      customerName: user?.name ?? 'Customer',
      customerPhone: _profilePhoneController.text.isNotEmpty
          ? _profilePhoneController.text
          : '+63 912 345 6789',
      deliveryAddress: _orderAddressController.text.trim(),
      waterType: waterTypeName,
      quantity: _orderQuantity,
      pricePerUnit: pricePerJug,
      paymentMethod: _selectedPaymentMethod,
    );

    if (mounted) {
      Helpers.showSnackBar(
        context,
        'Order ${newOrder.id} placed successfully! +${_orderQuantity * 10} points earned.',
      );
      setState(() {
        _selectedTab = 2; // Route directly to My Deliveries
        _activeSidebarMenu = 2;
      });

      if (_selectedPaymentMethod == 'GCash') {
        _showGcashPaymentDialog(newOrder, Theme.of(context).brightness == Brightness.dark);
      }
    }
  }

  void _showGcashPaymentDialog(OrderModel order, bool isDark) {
    GCashPaymentModal.show(
      context,
      order: order,
      paymentService: _paymentService,
      isDark: isDark,
      role: 'customer',
      onPaymentSuccess: () {
        if (mounted) {
          setState(() {
            _selectedTab = 2; // Switch to My Deliveries
            _activeSidebarMenu = 2;
          });
        }
      },
    );
  }

  void _sendSupportMessage(String text) async {
    if (text.trim().isEmpty) return;
    if (_isChatLoading) return; // Prevent multiple requests at once
    final userQuery = text.trim();

    setState(() {
      _chatMessages.add({'sender': 'Customer', 'message': userQuery});
      _chatInputController.clear();
      _isChatLoading = true;
      _chatMessages.add({'sender': 'AquaBot', 'message': 'Thinking...'});
    });

    _scrollToBottom();

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final user = auth.currentUser;

    try {
      final response = await AiSupportService.getChatResponse(
        query: userQuery,
        isDriver: false,
        isAdmin: false,
        userId: user?.id ?? '',
        userName: user?.name ?? 'Customer',
        orderProvider: orderProvider,
      );

      if (mounted) {
        setState(() {
          if (_chatMessages.isNotEmpty && _chatMessages.last['message'] == 'Thinking...') {
            _chatMessages.removeLast();
          }
          _chatMessages.add({'sender': 'AquaBot', 'message': response});
          _isChatLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (_chatMessages.isNotEmpty && _chatMessages.last['message'] == 'Thinking...') {
            _chatMessages.removeLast();
          }
          _chatMessages.add({
            'sender': 'AquaBot',
            'message': 'Sorry, I encountered an issue retrieving a response. Please check your connection and try again.'
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

  void _redeemRewardsCoupon(String couponName, int pointsCost) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final user = auth.currentUser;
    final rewardPoints = orderProvider.getCustomerRewardPoints(user?.id ?? '');

    if (rewardPoints < pointsCost) {
      Helpers.showSnackBar(
        context,
        'Insufficient loyalty reward points.',
        isError: true,
      );
      return;
    }
    Helpers.showSnackBar(context, 'Successfully redeemed: $couponName!');
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      drawer: (!isWide)
          ? Drawer(child: _buildSidebar(isDark, isDrawer: true))
          : null,
      appBar: isWide
          ? null
          : AppBar(
              backgroundColor: Colors.white,
              title: Text(
                _getTabTitle(),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.sync_rounded),
                  onPressed: _loadDashboardData,
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded),
                  onPressed: _handleLogout,
                ),
              ],
            ),
      body: Row(
        children: [
          if (isWide) _buildSidebar(isDark),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      if (isWide) _buildDesktopHeader(isDark),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _loadDashboardData,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white10 : const Color(0xFFD0E7EB),
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
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E293B),
                ),
              ),
              Row(
                children: [
                  const Text(
                    'Welcome back, ',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    '${auth.currentUser?.name ?? "Customer"}!',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
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
              color: isDark ? Colors.black26 : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search orders, services...',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: Colors.grey.shade400,
                  size: 18,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.only(bottom: 8),
              ),
            ),
          ),
          const SizedBox(width: 24),
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: Color(0xFF64748B),
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.chat_bubble_outline_rounded,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(width: 16),
          PopupMenuButton<String>(
            onSelected: (val) {
              if (val == 'logout') {
                _handleLogout();
              }
            },
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(
                      Icons.logout_rounded,
                      color: Color(0xFFEF4444),
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Log Out',
                      style: TextStyle(
                        color: Color(0xFFEF4444),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            child: CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
              child: Text(
                (auth.currentUser?.name ?? 'C').substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getTabTitle() {
    switch (_selectedTab) {
      case 0:
        return 'Customer Portal Dashboard';
      case 1:
        return 'Order Fresh Water Delivery';
      case 2:
        return 'My Deliveries Status';
      case 3:
        return 'Payment Transactions History';
      case 4:
        return 'Loyalty Points Store';
      case 5:
        return 'AquaBot Support Desk';
      case 6:
        return 'Profile Settings';
      default:
        return 'Customer Dashboard';
    }
  }

  Widget _buildSidebar(bool isDark, {bool isDrawer = false}) {
    final menuItems = [
      {'title': 'Dashboard', 'icon': Icons.home_rounded},
      {'title': 'Order Water', 'icon': Icons.local_drink_rounded},
      {'title': 'My Deliveries', 'icon': Icons.local_shipping_rounded},
      {'title': 'Payment History', 'icon': Icons.payment_rounded},
      {'title': 'Points & Rewards', 'icon': Icons.star_rounded},
      {'title': 'AI Chat Support', 'icon': Icons.chat_rounded},
      {'title': 'Settings', 'icon': Icons.settings_rounded},
    ];

    return Container(
      width: 260,
      height: double.infinity,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: 24,
              top: 24,
              right: 24,
              bottom: 16,
            ),
            child: Row(
              children: [
                const WaterDropletLogo(size: 36),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'JJAASS',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.primaryColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'Water Market',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
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
          _SidebarItemTile(
            icon: Icons.logout_rounded,
            title: 'Log Out',
            isSelected: false,
            textColor: const Color(0xFFEF4444),
            onTap: _handleLogout,
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14.0),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.white, Colors.white],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2F0F3), width: 1),
              ),
              child: Column(
                children: [
                  const WaterJugIllustration(width: 70, height: 80),
                  const SizedBox(height: 10),
                  const Text(
                    'Fresh & Pure',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Stay hydrated, stay healthy.',
                    style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedTabContent(bool isDark, double width) {
    switch (_selectedTab) {
      case 0:
        return _buildOverviewTab(isDark, width);
      case 1:
        return _buildOrderWaterTab(isDark);
      case 2:
        return _buildDeliveriesTab(isDark);
      case 3:
        return _buildPaymentHistoryTab(isDark);
      case 4:
        return _buildPointsStoreTab(isDark);
      case 5:
        return _buildAiSupportTab(isDark);
      case 6:
        return _buildSettingsTab(isDark);
      default:
        return _buildOverviewTab(isDark, width);
    }
  }

  // TAB 0: DASHBOARD / OVERVIEW
  Widget _buildOverviewTab(bool isDark, double width) {
    final isDesktop = width >= 1100;
    final auth = Provider.of<AuthProvider>(context);
    final orderProvider = Provider.of<OrderProvider>(context);
    final user = auth.currentUser;
    final customerId = user?.id ?? '';

    final myOrders = orderProvider.getCustomerOrders(customerId);
    final activeOrdersCount = myOrders
        .where(
          (o) =>
              o.orderStatus != OrderStatus.completed &&
              o.orderStatus != OrderStatus.cancelled,
        )
        .length;
    final rewardPoints = orderProvider.getCustomerRewardPoints(customerId);

    final pendingGcashOrders = myOrders
        .where((o) => o.paymentStatus == 'Pending' && o.paymentMethod == 'GCash')
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (pendingGcashOrders.isNotEmpty) ...[
            InkWell(
              onTap: () => _showGcashPaymentDialog(pendingGcashOrders.first, isDark),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: CustomerDecorations.gcashBanner,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Unpaid Order ${pendingGcashOrders.first.id}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          Text(
                            'Total: ₱${pendingGcashOrders.first.totalAmount.toStringAsFixed(2)} • Tap to open GCash checkout',
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.bolt_rounded, size: 14, color: Color(0xFF007DFE)),
                          SizedBox(width: 2),
                          Text(
                            'Pay Now',
                            style: TextStyle(
                              color: Color(0xFF007DFE),
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Active Orders',
                  '$activeOrdersCount',
                  'Current deliveries',
                  Icons.local_drink_rounded,
                  AppTheme.primaryColor,
                  isDark,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Reward Points',
                  '$rewardPoints pts',
                  'Points available',
                  Icons.star_rounded,
                  AppTheme.secondaryColor,
                  isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: Column(children: [_buildTransactionsCard(isDark)]),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      _buildQuickActionsCard(isDark),
                      const SizedBox(height: 16),
                      _buildMiniAiSupportCard(isDark),
                    ],
                  ),
                ),
              ],
            )
          else
            Column(
              children: [
                _buildTransactionsCard(isDark),
                const SizedBox(height: 16),
                _buildQuickActionsCard(isDark),
                const SizedBox(height: 16),
                _buildMiniAiSupportCard(isDark),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return CustomerStatCard(
      title: title,
      value: value,
      subtitle: subtitle,
      icon: icon,
      color: color,
      isDark: isDark,
    );
  }

  Widget _buildTransactionsCard(bool isDark) {
    final auth = Provider.of<AuthProvider>(context);
    final orderProvider = Provider.of<OrderProvider>(context);
    final user = auth.currentUser;
    final myOrders = orderProvider.getCustomerOrders(user?.id ?? '');

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: CustomerDecorations.card(isDark: isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Transactions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _selectedTab = 3),
                child: const Text(
                  'View All',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          myOrders.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(child: Text('No transactions yet.')),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: min(myOrders.length, 4),
                  itemBuilder: (context, index) {
                    final tx = myOrders[index];
                    final isCompleted =
                        tx.orderStatus == OrderStatus.completed ||
                        tx.paymentStatus == 'Paid';
                    final color = isCompleted
                        ? const Color(0xFF0284C7)
                        : const Color(0xFFF59E0B);

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.02)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? Colors.white10
                                : const Color(0xFFF1F5F9),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.08),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.payment_rounded,
                                color: color,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tx.txnId,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Order ${tx.id} • ${tx.createdAt.toString().split(' ')[0]}',
                                    style: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  tx.formattedTotal,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: color.withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: Text(
                                    tx.paymentStatus,
                                    style: TextStyle(
                                      color: color,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
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
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard(bool isDark) {
    final actions = [
      {
        'title': 'Order Water',
        'icon': Icons.local_drink_rounded,
        'color': const Color(0xFF0284C7),
        'tab': 1,
      },
      {
        'title': 'Points Store',
        'icon': Icons.stars_rounded,
        'color': const Color(0xFF0284C7),
        'tab': 4,
      },
      {
        'title': 'Chat Support',
        'icon': Icons.support_agent_rounded,
        'color': const Color(0xFF0EA5E9),
        'tab': 5,
      },
      {
        'title': 'Profile Settings',
        'icon': Icons.manage_accounts_rounded,
        'color': const Color(0xFF10B981),
        'tab': 6,
      },
    ];

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
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
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: actions.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.4,
            ),
            itemBuilder: (context, index) {
              final act = actions[index];
              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedTab = act['tab'] as int;
                    _activeSidebarMenu = act['tab'] as int;
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: (act['color'] as Color).withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (act['color'] as Color).withValues(alpha: 0.1),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        act['icon'] as IconData,
                        color: act['color'] as Color,
                        size: 22,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        act['title'] as String,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMiniAiSupportCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          const SizedBox(height: 14),
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
                    controller: _chatInputController,
                    onSubmitted: (val) {
                      _sendSupportMessage(val);
                      setState(() {
                        _selectedTab = 5; // Route to full support tab
                        _activeSidebarMenu = 5;
                      });
                    },
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Type your message...',
                      hintStyle: TextStyle(color: Colors.grey.shade400),
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
                  onPressed: () {
                    _sendSupportMessage(_chatInputController.text);
                    setState(() {
                      _selectedTab = 5; // Route to full support tab
                      _activeSidebarMenu = 5;
                    });
                  },
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

  // TAB 1: ORDER WATER FORM
  Widget _buildOrderWaterTab(bool isDark) {
    final orderProvider = Provider.of<OrderProvider>(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Place a Fresh Water Order',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Water Type Dropdown
                const Text(
                  'Water Type Selection',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _selectedWaterType,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  items: orderProvider.waterProducts.map((prod) {
                    final name = prod['name'] as String;
                    final price = prod['price'] as double;
                    return DropdownMenuItem<String>(
                      value: name,
                      child: Text('$name (₱${price.toStringAsFixed(2)})'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedWaterType = val;
                      });
                    }
                  },
                ),
                const SizedBox(height: 20),

                // Quantity Row
                const Text(
                  'Quantity (5-Gallon Slim/Round)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        color: AppTheme.primaryColor,
                      ),
                      onPressed: () {
                        if (_orderQuantity > 1) {
                          setState(() => _orderQuantity--);
                        }
                      },
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$_orderQuantity',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.add_circle_outline,
                        color: AppTheme.primaryColor,
                      ),
                      onPressed: () {
                        if (_orderQuantity < 20) {
                          setState(() => _orderQuantity++);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Delivery Address
                const Text(
                  'Delivery Address',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _orderAddressController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Enter your exact home address...',
                  ),
                ),
                const SizedBox(height: 20),

                // Payment Method
                const Text(
                  'Payment Method',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _selectedPaymentMethod,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Cash on Delivery',
                      child: Text('Cash on Delivery (COD)'),
                    ),
                    DropdownMenuItem(
                      value: 'GCash',
                      child: Text('GCash Mobile Payment'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedPaymentMethod = val;
                      });
                    }
                  },
                ),
                const SizedBox(height: 32),

                // Submit Button
                ElevatedButton(
                  onPressed: _submitWaterOrder,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: AppTheme.primaryColor,
                  ),
                  child: const Text(
                    'Confirm Order Delivery',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  // TAB 2: MY DELIVERIES STATUS TRACKER
  Widget _buildDeliveriesTab(bool isDark) {
    final auth = Provider.of<AuthProvider>(context);
    final orderProvider = Provider.of<OrderProvider>(context);
    final user = auth.currentUser;
    final myOrders = orderProvider.getCustomerOrders(user?.id ?? '');

    final activeDelivery = myOrders.any((o) => o.orderStatus == OrderStatus.onDelivery)
        ? myOrders.firstWhere((o) => o.orderStatus == OrderStatus.onDelivery)
        : null;
    final pendingGcashOrders = myOrders
        .where((o) => o.paymentStatus == 'Pending' && o.paymentMethod == 'GCash')
        .toList();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Track Deliveries',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              if (pendingGcashOrders.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF007DFE).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF007DFE).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.account_balance_wallet_rounded, size: 14, color: Color(0xFF007DFE)),
                      const SizedBox(width: 4),
                      Text(
                        '${pendingGcashOrders.length} Unpaid GCash',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF007DFE)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (pendingGcashOrders.isNotEmpty) ...[
            const SizedBox(height: 12),
            InkWell(
              onTap: () => _showGcashPaymentDialog(pendingGcashOrders.first, isDark),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF007DFE), Color(0xFF0056B3)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF007DFE).withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.payment_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Action Required: Pay GCash for ${pendingGcashOrders.first.id}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          Text(
                            'Amount: ₱${pendingGcashOrders.first.totalAmount.toStringAsFixed(2)} • Tap to complete payment',
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Pay Now',
                        style: TextStyle(
                          color: Color(0xFF007DFE),
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (activeDelivery != null) ...[
            Container(
              height: 220,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: GoogleMapWidget(
                  destinationLat: activeDelivery.latitude,
                  destinationLng: activeDelivery.longitude,
                  destinationAddress: activeDelivery.deliveryAddress,
                  isDriverView: false,
                  orderId: activeDelivery.id,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Expanded(
            child: myOrders.isEmpty
                ? const Center(child: Text('No orders yet.'))
                : ListView.builder(
                    itemCount: myOrders.length,
                    itemBuilder: (context, index) {
                      final order = myOrders[index];
                      final isDone = order.orderStatus == OrderStatus.completed;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: order.orderStatus.color.withValues(
                                    alpha: 0.08,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isDone
                                      ? Icons.check_circle_rounded
                                      : Icons.local_shipping_rounded,
                                  color: order.orderStatus.color,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      order.id,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      order.itemsSummary,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      order.deliveryAddress,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                    if (order.driverName != null) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.person_pin_rounded,
                                            size: 14,
                                            color: AppTheme.primaryColor,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Driver: ${order.driverName}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.primaryColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    order.createdAt.toString().split(' ')[0],
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  if (order.paymentStatus == 'Pending' && order.paymentMethod == 'GCash') ...[
                                    const SizedBox(height: 6),
                                    InkWell(
                                      onTap: () => _showGcashPaymentDialog(order, isDark),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFF007DFE), Color(0xFF0056B3)],
                                          ),
                                          borderRadius: BorderRadius.circular(8),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF007DFE).withValues(alpha: 0.3),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.bolt_rounded, size: 12, color: Colors.white),
                                            SizedBox(width: 3),
                                            Text(
                                              '⚡ Pay GCash',
                                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                  ],
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: order.orderStatus.color.withValues(
                                        alpha: 0.08,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
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

  // TAB 3: PAYMENT HISTORY
  Widget _buildPaymentHistoryTab(bool isDark) {
    final auth = Provider.of<AuthProvider>(context);
    final orderProvider = Provider.of<OrderProvider>(context);
    final user = auth.currentUser;
    final myOrders = orderProvider.getCustomerOrders(user?.id ?? '');

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Invoices & Transactions History',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: myOrders.isEmpty
                ? const Center(child: Text('No transaction history yet.'))
                : ListView.builder(
                    itemCount: myOrders.length,
                    itemBuilder: (context, index) {
                      final tx = myOrders[index];
                      final isPaid = tx.paymentStatus == 'Paid';
                      final color = isPaid
                          ? Colors.green
                          : Colors.amber.shade700;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: color.withValues(alpha: 0.08),
                            child: Icon(Icons.payment_rounded, color: color),
                          ),
                          title: Text(
                            tx.txnId,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Order: ${tx.id} • ${tx.paymentMethod}\nDate: ${tx.createdAt.toString().split('.')[0]}',
                          ),
                          isThreeLine: true,
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                tx.formattedTotal,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                              if (tx.paymentStatus == 'Pending' && tx.paymentMethod == 'GCash') ...[
                                const SizedBox(height: 4),
                                InkWell(
                                  onTap: () => _showGcashPaymentDialog(tx, isDark),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF007DFE), Color(0xFF0056B3)],
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.bolt_rounded, size: 10, color: Colors.white),
                                        SizedBox(width: 2),
                                        Text(
                                          '⚡ Pay GCash',
                                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  tx.paymentStatus,
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
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

  // TAB 4: POINTS & REWARDS STORE
  Widget _buildPointsStoreTab(bool isDark) {
    final auth = Provider.of<AuthProvider>(context);
    final orderProvider = Provider.of<OrderProvider>(context);
    final user = auth.currentUser;
    final rewardPoints = orderProvider.getCustomerRewardPoints(user?.id ?? '');

    final rewardItems = [
      {
        'name': 'Free Refill Coupon (19L Purified)',
        'cost': 100,
        'desc': 'Get one 19-Liter purified container refilled free.',
      },
      {
        'name': 'Free Refill Coupon (19L Alkaline)',
        'cost': 120,
        'desc': 'Get one 19-Liter alkaline container refilled free.',
      },
      {
        'name': '₱50 Store Discount Voucher',
        'cost': 80,
        'desc': 'Avail a flat ₱50 discount on your next transaction.',
      },
      {
        'name': 'JJAASS Premium Water Bottle',
        'cost': 250,
        'desc': 'Redeem a branded metal water flask at our refilling hub.',
      },
    ];

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0284C7), Color(0xFF0284C7)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Loyalty Member Balance',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$rewardPoints Points',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const Icon(Icons.stars_rounded, color: Colors.white, size: 40),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Redeem Rewards Catalogue',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: rewardItems.length,
              itemBuilder: (context, index) {
                final item = rewardItems[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['name'] as String,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item['desc'] as String,
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: () => _redeemRewardsCoupon(
                            item['name'] as String,
                            item['cost'] as int,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.secondaryColor,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          child: Text('${item['cost']} pts'),
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

  // TAB 5: AI SUPPORT DESK (Full chat interface)
  Widget _buildAiSupportTab(bool isDark) {
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
                    'AquaBot Virtual Support',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: _chatScrollController,
                padding: const EdgeInsets.all(16.0),
                itemCount: _chatMessages.length,
                itemBuilder: (context, index) {
                  final msg = _chatMessages[index];
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
                      controller: _chatInputController,
                      onSubmitted: _sendSupportMessage,
                      decoration: const InputDecoration(
                        hintText: 'Type your message...',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FloatingActionButton(
                    onPressed: () =>
                        _sendSupportMessage(_chatInputController.text),
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

  // TAB 6: SETTINGS
  Widget _buildSettingsTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Profile Information',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
              children: [
                TextField(
                  controller: _profileNameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _profilePhoneController,
                  decoration: const InputDecoration(labelText: 'Phone Number'),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Helpers.showSnackBar(
                      context,
                      'Profile information updated successfully!',
                    );
                  },
                  child: const Text('Save Changes'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Preferences',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Card(
            child: SwitchListTile(
              title: const Text(
                'Push Notifications',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              subtitle: const Text(
                'Get alerts about dispatch status and promo discount coupons.',
                style: TextStyle(fontSize: 11),
              ),
              value: _notificationsEnabled,
              onChanged: (val) {
                setState(() => _notificationsEnabled = val);
                Helpers.showSnackBar(context, 'Notification settings updated.');
              },
              activeThumbColor: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
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
    if (active) {
      backgroundColor = AppTheme.primaryColor;
    } else if (_isHovered) {
      backgroundColor = const Color(0xFF334155); // Dark Gray hover
    } else {
      backgroundColor = Colors.transparent;
    }

    final Color contentColor = highlighted
        ? Colors.white
        : (widget.textColor ?? const Color(0xFF475569));

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
