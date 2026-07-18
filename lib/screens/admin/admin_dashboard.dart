import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/water_widgets.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  bool _isActionLoading = false;
  Map<String, dynamic> _statsData = {};
  List<UserModel> _allUsers = [];
  List<UserModel> _filteredUsers = [];

  // Tab indexing maps directly to sidebar:
  // 0: Dashboard, 1: Orders, 2: Deliveries, 3: Customers, 4: Inventory, 5: Payments, 6: Reports, 7: AI Chat Support, 8: Users, 9: Settings
  int _selectedTab = 0; 
  int _activeSidebarMenu = 0;

  // Search/filter states for Users
  final TextEditingController _searchController = TextEditingController();
  String _selectedRoleFilter = 'All';

  // State variables for mock orders (interactive status updates)
  late List<Map<String, dynamic>> _mockOrders;

  // State variables for mock inventory
  double _purifiedWaterLevel = 0.85; // percentage
  double _alkalineWaterLevel = 0.70;
  int _emptyContainerStocks = 140;
  int _refilledContainerStocks = 90;

  // State variables for interactive support chat
  final List<Map<String, dynamic>> _supportMessages = [
    {'sender': 'AquaBot', 'message': "Hello! I'm AquaBot 💧 How can I help you today?"},
  ];
  final TextEditingController _supportInputController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();

  // Chart data simulation (weekly revenue)
  final List<double> _weeklyRevenueData = [5000, 12000, 10000, 17000, 12450, 19000, 23000];

  // Orders status filter
  String _activeOrderFilter = 'All';

  @override
  void initState() {
    super.initState();
    _initMockOrders();
    _loadAllDashboardData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _supportInputController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  void _initMockOrders() {
    _mockOrders = [
      {'id': '#ORD-000128', 'customer': 'Juan Dela Cruz', 'products': '2 x 19L Purified', 'address': 'Brgy. San Isidro', 'status': 'On Delivery', 'total': '₱100.00', 'date': 'May 16, 2024', 'color': const Color(0xFF0284C7), 'time': '10:30 AM'},
      {'id': '#ORD-000127', 'customer': 'Maria Santos', 'products': '3 x 19L Purified', 'address': 'Brgy. Poblacion', 'status': 'Completed', 'total': '₱150.00', 'date': 'May 16, 2024', 'color': const Color(0xFF009CA6), 'time': '09:15 AM'},
      {'id': '#ORD-000126', 'customer': 'Pedro Reyes', 'products': '1 x 19L Purified', 'address': 'Brgy. Mabini', 'status': 'Pending', 'total': '₱50.00', 'date': 'May 16, 2024', 'color': const Color(0xFFF59E0B), 'time': '08:45 AM'},
      {'id': '#ORD-000125', 'customer': 'Anna Garcia', 'products': '2 x 19L Alkaline', 'address': 'Brgy. San Vicente', 'status': 'Completed', 'total': '₱100.00', 'date': 'May 15, 2024', 'color': const Color(0xFF009CA6), 'time': 'Yesterday'},
      {'id': '#ORD-000124', 'customer': 'John Paul', 'products': '1 x 19L Purified', 'address': 'Brgy. Poblacion', 'status': 'Cancelled', 'total': '₱50.00', 'date': 'May 15, 2024', 'color': const Color(0xFFEF4444), 'time': 'Yesterday'},
    ];
  }

  Future<void> _loadAllDashboardData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final stats = await _apiService.getAdminDashboardData();
      final users = await _apiService.getAdminUsers();

      if (mounted) {
        setState(() {
          _statsData = stats;
          _allUsers = users;
          _filteredUsers = users;
          _isLoading = false;
        });
        _applyFilters();
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(context, 'Failed to sync dashboard data.', isError: true);
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
        final matchesQuery = user.name.toLowerCase().contains(query) ||
            user.email.toLowerCase().contains(query);
        final matchesRole = _selectedRoleFilter == 'All' ||
            user.role.name.toLowerCase() == _selectedRoleFilter.toLowerCase();
        return matchesQuery && matchesRole;
      }).toList();
    });
  }

  void _updateOrderStatus(String id, String newStatus) {
    setState(() {
      for (var order in _mockOrders) {
        if (order['id'] == id) {
          order['status'] = newStatus;
          if (newStatus == 'Completed') {
            order['color'] = const Color(0xFF009CA6);
          } else if (newStatus == 'On Delivery') {
            order['color'] = const Color(0xFF0284C7);
          } else if (newStatus == 'Pending') {
            order['color'] = const Color(0xFFF59E0B);
          } else if (newStatus == 'Cancelled') {
            order['color'] = const Color(0xFFEF4444);
          }
        }
      }
    });
    Helpers.showSnackBar(context, 'Order $id status updated to $newStatus.');
  }

  void _sendSupportMessage(String text) {
    if (text.trim().isEmpty) return;
    setState(() {
      _supportMessages.add({'sender': 'Admin', 'message': text});
      _supportInputController.clear();
      
      // Auto reply simulation
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() {
            _supportMessages.add({
              'sender': 'AquaBot',
              'message': 'Received! I will dispatch standard response or notify team regarding: "$text"'
            });
          });
          // Scroll to bottom
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
      });
    });
  }

  Future<void> _handleUpdateRole(UserModel user, UserRole newRole) async {
    setState(() {
      _isActionLoading = true;
    });

    try {
      final success = await _apiService.updateUserRole(user.id, newRole);
      if (success && mounted) {
        Helpers.showSnackBar(context, 'Updated ${user.name} to ${newRole.name}.');
        final updatedUsers = await _apiService.getAdminUsers();
        setState(() {
          _allUsers = updatedUsers;
        });
        _applyFilters();
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(context, 'Failed to update user role.', isError: true);
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      drawer: (!isWide) ? Drawer(child: _buildSidebar(isDark, isDrawer: true)) : null,
      appBar: isWide
          ? null
          : AppBar(
              backgroundColor: isDark ? AppTheme.darkSurface : const Color(0xFFECF8FA),
              title: Text(
                _getTabTitle(),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.sync_rounded),
                  tooltip: 'Sync Console',
                  onPressed: _loadAllDashboardData,
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded),
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
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      if (isWide) _buildDesktopHeader(isDark),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: _buildSelectedTabContent(isDark, media.size.width),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : const Color(0xFFECF8FA),
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
                children: const [
                  Text(
                    'Welcome back, ',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    'Admin!',
                    style: TextStyle(
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
                hintText: 'Search anything...',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade400, size: 18),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.only(bottom: 8),
              ),
            ),
          ),
          const SizedBox(width: 24),
          Stack(
            children: [
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFF64748B)),
                tooltip: 'Notifications',
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Color(0xFF009CA6), shape: BoxShape.circle),
                  child: const Text('3', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
          Stack(
            children: [
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF64748B)),
                tooltip: 'Messages',
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Color(0xFF0284C7), shape: BoxShape.circle),
                  child: const Text('2', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
          const SizedBox(width: 16),
          Container(
            height: 32,
            width: 1,
            color: const Color(0xFFE2E8F0),
          ),
          const SizedBox(width: 16),
          PopupMenuButton<String>(
            onSelected: (val) {
              if (val == 'logout') {
                _handleLogout();
              }
            },
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 18),
                    SizedBox(width: 8),
                    Text('Log Out', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.12),
                  child: const Text('A', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      'Admin',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                    ),
                    Text(
                      'Administrator',
                      style: TextStyle(color: Colors.grey, fontSize: 10),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey, size: 18),
              ],
            ),
          ),
        ],
      ),
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
        return 'Customers Database';
      case 4:
        return 'Inventory & Reserves';
      case 5:
        return 'Payments Transactions';
      case 6:
        return 'Analytics & Reports';
      case 7:
        return 'AquaBot AI Support';
      case 8:
        return 'Accounts Management';
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
      {'title': 'Customers', 'icon': Icons.people_alt_rounded},
      {'title': 'Inventory', 'icon': Icons.inventory_2_rounded},
      {'title': 'Payments', 'icon': Icons.payment_rounded},
      {'title': 'Reports', 'icon': Icons.analytics_rounded},
      {'title': 'AI Chat Support', 'icon': Icons.chat_rounded},
      {'title': 'Users', 'icon': Icons.manage_accounts_rounded},
      {'title': 'Settings', 'icon': Icons.settings_rounded},
    ];

    return Container(
      width: 260,
      height: double.infinity,
      color: isDark ? AppTheme.darkSurface : const Color(0xFFF1F9FB),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 24, top: 24, right: 24, bottom: 16),
            child: Row(
              children: [
                const WaterDropletLogo(size: 36),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'JJAASS',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.primaryColor, letterSpacing: 0.5),
                    ),
                    Text(
                      'Water Market',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      'WATER REFILLING STATION',
                      style: TextStyle(fontSize: 6, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: Colors.grey),
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
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 2.0),
                  child: ListTile(
                    onTap: () {
                      setState(() {
                        _activeSidebarMenu = index;
                        _selectedTab = index;
                      });
                      if (isDrawer) {
                        Navigator.of(context).pop();
                      }
                    },
                    selected: isSelected,
                    selectedTileColor: AppTheme.primaryColor,
                    iconColor: const Color(0xFF64748B),
                    selectedColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    dense: true,
                    leading: Icon(
                      item['icon'] as IconData,
                      size: 20,
                      color: isSelected ? Colors.white : const Color(0xFF64748B),
                    ),
                    title: Text(
                      item['title'] as String,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                        color: isSelected ? Colors.white : const Color(0xFF475569),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 2.0),
            child: ListTile(
              onTap: _handleLogout,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              dense: true,
              leading: const Icon(Icons.logout_rounded, size: 20, color: Color(0xFFEF4444)),
              title: const Text(
                'Log Out',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFEF4444),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14.0),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFECF8FA), Color(0xFFE0F7FA)],
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
                    'Pure Water,\nBetter Life!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppTheme.primaryColor, height: 1.2),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Thank you for choosing JJAASS Water Market.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 9, color: Colors.grey.shade600, height: 1.3),
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
                    '${_mockOrders.length}',
                    '18% from last week',
                    Icons.local_drink_rounded,
                    const Color(0xFF009CA6),
                    isDark,
                    isUpTrend: true,
                  ),
                  _buildStatCard(
                    'Deliveries Today',
                    '24',
                    '14% from yesterday',
                    Icons.local_shipping_rounded,
                    const Color(0xFF0284C7),
                    isDark,
                    isUpTrend: true,
                  ),
                  _buildStatCard(
                    'Total Customers',
                    '356',
                    '12% from last month',
                    Icons.group_rounded,
                    const Color(0xFF0EA5E9),
                    isDark,
                    isUpTrend: true,
                  ),
                  _buildStatCard(
                    'Total Revenue',
                    '₱45,680',
                    '20% from last week',
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
                Expanded(flex: 2, child: _buildOrderStatusDonutCard(isDark)),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: _buildRecentOrdersListCard(isDark)),
              ],
            )
          else
            Column(
              children: [
                _buildSalesOverviewCard(isDark),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildOrderStatusDonutCard(isDark)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildRecentOrdersListCard(isDark)),
                  ],
                ),
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
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0), width: 1.0),
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
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      isUpTrend ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                      color: isUpTrend ? const Color(0xFF10B981) : Colors.red,
                      size: 13,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      trend,
                      style: TextStyle(color: isUpTrend ? const Color(0xFF10B981) : Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesOverviewCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      height: 310,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0), width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Sales Overview', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: const [
                    Text('This Week', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                    SizedBox(width: 4),
                    Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: Color(0xFF475569)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: SizedBox(
              width: double.infinity,
              child: SalesOverviewLineChart(dataPoints: _weeklyRevenueData),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].map((day) {
              return Text(day, style: TextStyle(fontSize: 11, color: Colors.grey.shade400, fontWeight: FontWeight.bold));
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderStatusDonutCard(bool isDark) {
    final legendItems = [
      {'title': 'Completed', 'pct': '53%', 'color': const Color(0xFF009CA6)},
      {'title': 'On Delivery', 'pct': '25%', 'color': const Color(0xFF0284C7)},
      {'title': 'Pending', 'pct': '14%', 'color': const Color(0xFFF59E0B)},
      {'title': 'Cancelled', 'pct': '8%', 'color': const Color(0xFFEF4444)},
    ];

    return Container(
      padding: const EdgeInsets.all(20.0),
      height: 310,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0), width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Orders Status', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
          const SizedBox(height: 20),
          const Expanded(child: OrderStatusDonutChart()),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: legendItems.map((item) {
              return Column(
                children: [
                  Row(
                    children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: item['color'] as Color, shape: BoxShape.circle)),
                      const SizedBox(width: 4),
                      Text(item['title'] as String, style: TextStyle(fontSize: 9, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  Text(item['pct'] as String, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentOrdersListCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      height: 310,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0), width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Recent Orders', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
              GestureDetector(
                onTap: () => setState(() => _selectedTab = 1),
                child: const Text('View All', style: TextStyle(fontSize: 11, color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: min(_mockOrders.length, 5),
              itemBuilder: (context, index) {
                final order = _mockOrders[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: (order['color'] as Color).withOpacity(0.08),
                        child: Icon(Icons.person, size: 14, color: order['color'] as Color),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(order['id'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF1E293B))),
                            Text('${order['customer']} • ${order['products']}', style: TextStyle(color: Colors.grey.shade500, fontSize: 10), overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (order['color'] as Color).withOpacity(0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              order['status'] as String,
                              style: TextStyle(color: order['color'] as Color, fontSize: 8, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(order['time'] as String, style: TextStyle(color: Colors.grey.shade400, fontSize: 9)),
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

  Widget _buildRecentOrdersTableCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0), width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Recent Orders Details', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
              OutlinedButton(
                onPressed: () => setState(() => _selectedTab = 1),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Row(
                  children: const [
                    Text('View All Orders', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded, size: 12, color: Color(0xFF64748B)),
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
              dataRowHeight: 48,
              columns: const [
                DataColumn(label: Text('Order ID', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                DataColumn(label: Text('Customer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                DataColumn(label: Text('Products', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                DataColumn(label: Text('Address', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                DataColumn(label: Text('Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                DataColumn(label: Text('Total', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                DataColumn(label: Text('Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
              ],
              rows: _mockOrders.map((data) {
                return DataRow(cells: [
                  DataCell(Text(data['id'] as String, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryColor))),
                  DataCell(Text(data['customer'] as String, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)))),
                  DataCell(Text(data['products'] as String, style: const TextStyle(fontSize: 12, color: Color(0xFF475569)))),
                  DataCell(Text(data['address'] as String, style: const TextStyle(fontSize: 12, color: Color(0xFF475569)))),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: (data['color'] as Color).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: (data['color'] as Color).withOpacity(0.15)),
                      ),
                      child: Text(
                        data['status'] as String,
                        style: TextStyle(color: data['color'] as Color, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  DataCell(Text(data['total'] as String, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)))),
                  DataCell(Text(data['date'] as String, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
                ]);
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
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0), width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Quick Actions', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.1,
            children: [
              _buildQuickActionItem('New Order', Icons.add_shopping_cart_rounded, const Color(0xFF009CA6), () => setState(() => _selectedTab = 1)),
              _buildQuickActionItem('Add Customer', Icons.person_add_alt_1_rounded, const Color(0xFF0284C7), () => setState(() => _selectedTab = 3)),
              _buildQuickActionItem('New Delivery', Icons.local_shipping_rounded, const Color(0xFF0EA5E9), () => setState(() => _selectedTab = 2)),
              _buildQuickActionItem('Add Inventory', Icons.add_box_rounded, const Color(0xFF10B981), () => setState(() => _selectedTab = 4)),
              _buildQuickActionItem('View Reports', Icons.analytics_rounded, const Color(0xFF6366F1), () => setState(() => _selectedTab = 6)),
              _buildQuickActionItem('Payments', Icons.payments_rounded, const Color(0xFFEC4899), () => setState(() => _selectedTab = 5)),
              _buildQuickActionItem('AI Support', Icons.support_agent_rounded, const Color(0xFF8B5CF6), () => setState(() => _selectedTab = 7)),
              _buildQuickActionItem('Users', Icons.people_alt_rounded, const Color(0xFF64748B), () => setState(() => _selectedTab = 8)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionItem(String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.1), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
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
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0), width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.psychology_rounded, color: AppTheme.primaryColor, size: 20),
              SizedBox(width: 8),
              Text('AI Chat Support', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F9FB),
              borderRadius: const BorderRadius.only(topRight: Radius.circular(12), bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
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
                      Text('AquaBot', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                      SizedBox(height: 2),
                      Text('Hello! I\'m AquaBot 💧 How can I help you today?', style: TextStyle(fontSize: 11, color: Color(0xFF475569), height: 1.3)),
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
                decoration: BoxDecoration(color: AppTheme.primaryColor, borderRadius: BorderRadius.circular(8)),
                child: IconButton(
                  onPressed: () => _sendSupportMessage(_supportInputController.text),
                  icon: const Icon(Icons.send_rounded, size: 14, color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // TAB 1: ORDERS MANAGEMENT (Interactive Order status updater)
  Widget _buildOrdersTab(bool isDark) {
    final filtered = _activeOrderFilter == 'All'
        ? _mockOrders
        : _mockOrders.where((o) => o['status'] == _activeOrderFilter).toList();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Tabs
          Row(
            children: ['All', 'Pending', 'On Delivery', 'Completed', 'Cancelled'].map((status) {
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
            }).toList(),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('No orders match this status.'))
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final order = filtered[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    order['id'] as String,
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: (order['color'] as Color).withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: (order['color'] as Color).withOpacity(0.2)),
                                    ),
                                    child: Text(
                                      order['status'] as String,
                                      style: TextStyle(color: order['color'] as Color, fontWeight: FontWeight.bold, fontSize: 10),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text('Customer: ${order['customer']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text('Products: ${order['products']}'),
                              Text('Delivery Address: ${order['address']}'),
                              Text('Total Amount: ${order['total']}'),
                              const Divider(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  const Text('Change Status: ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                  const SizedBox(width: 8),
                                  ...['Pending', 'On Delivery', 'Completed', 'Cancelled'].map((st) {
                                    if (st == order['status']) return const SizedBox.shrink();
                                    return Container(
                                      margin: const EdgeInsets.only(left: 6),
                                      child: OutlinedButton(
                                        onPressed: () => _updateOrderStatus(order['id'] as String, st),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        child: Text(st, style: const TextStyle(fontSize: 10)),
                                      ),
                                    );
                                  }).toList(),
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

  // TAB 2: DELIVERIES FLEET (Mock GPS monitor)
  Widget _buildDeliveriesTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Active Drivers', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                        SizedBox(height: 6),
                        Text('4 Drivers Online', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Pending Shipments', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                        SizedBox(height: 6),
                        Text('8 Packages', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Live Fleet GPS Route Monitor', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                SizedBox(
                  height: 240,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _FleetMapPainter(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // TAB 3: CUSTOMERS DATABASE
  Widget _buildCustomersTab(bool isDark) {
    final mockCustomers = [
      {'name': 'Juan Dela Cruz', 'email': 'juan@gmail.com', 'phone': '+63 912 3456', 'orders': '14 orders', 'status': 'Active'},
      {'name': 'Maria Santos', 'email': 'maria.santos@yahoo.com', 'phone': '+63 908 1112', 'orders': '28 orders', 'status': 'Active'},
      {'name': 'Pedro Reyes', 'email': 'pedro.r@gmail.com', 'phone': '+63 919 4455', 'orders': '8 orders', 'status': 'Active'},
      {'name': 'Anna Garcia', 'email': 'anna.garcia@outlook.com', 'phone': '+63 922 9988', 'orders': '19 orders', 'status': 'Active'},
      {'name': 'John Paul', 'email': 'jp.delarosa@gmail.com', 'phone': '+63 933 5544', 'orders': '5 orders', 'status': 'Suspended'},
    ];

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TextField(
            decoration: InputDecoration(
              hintText: 'Search customers...',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: mockCustomers.length,
              itemBuilder: (context, index) {
                final cust = mockCustomers[index];
                final isActive = cust['status'] == 'Active';
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                      child: Text(cust['name']!.substring(0, 1), style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                    ),
                    title: Text(cust['name']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${cust['email']} • ${cust['phone']}'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(cust['orders']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (isActive ? Colors.green : Colors.red).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            cust['status']!,
                            style: TextStyle(color: isActive ? Colors.green : Colors.red, fontSize: 9, fontWeight: FontWeight.bold),
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

  // TAB 4: INVENTORY & RESERVES
  Widget _buildInventoryTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Station Stock Levels', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  _buildInventoryStockRow('Purified Water Reserve', _purifiedWaterLevel, () {
                    setState(() {
                      _purifiedWaterLevel = min(1.0, _purifiedWaterLevel + 0.15);
                    });
                    Helpers.showSnackBar(context, 'Refilled Purified Water Reserve +15%.');
                  }),
                  const Divider(height: 32),
                  _buildInventoryStockRow('Alkaline Water Reserve', _alkalineWaterLevel, () {
                    setState(() {
                      _alkalineWaterLevel = min(1.0, _alkalineWaterLevel + 0.15);
                    });
                    Helpers.showSnackBar(context, 'Refilled Alkaline Water Reserve +15%.');
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Container Inventory Reserves', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Empty Containers Logged', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text('$_emptyContainerStocks units', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _emptyContainerStocks += 20;
                            });
                          },
                          icon: const Icon(Icons.add, size: 14),
                          label: const Text('Add stocks', style: TextStyle(fontSize: 10)),
                          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Refilled Containers Stock', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text('$_refilledContainerStocks units', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _refilledContainerStocks += 20;
                            });
                          },
                          icon: const Icon(Icons.add, size: 14),
                          label: const Text('Add Refills', style: TextStyle(fontSize: 10)),
                          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryStockRow(String title, double value, VoidCallback onRefill) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 10,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                ),
              ),
              const SizedBox(height: 4),
              Text('${(value * 100).toStringAsFixed(0)}% storage capacity left', style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
        const SizedBox(width: 24),
        OutlinedButton.icon(
          onPressed: onRefill,
          icon: const Icon(Icons.water_drop_rounded, size: 14),
          label: const Text('Refill'),
        ),
      ],
    );
  }

  // TAB 5: PAYMENTS TRANSACTIONS
  Widget _buildPaymentsTab(bool isDark) {
    final mockPayments = [
      {'id': '#TXN-902118', 'order': '#ORD-000128', 'method': 'GCash', 'amount': '₱100.00', 'date': 'May 16, 2024, 10:32 AM', 'status': 'Successful'},
      {'id': '#TXN-902117', 'order': '#ORD-000127', 'method': 'Cash', 'amount': '₱150.00', 'date': 'May 16, 2024, 09:16 AM', 'status': 'Successful'},
      {'id': '#TXN-902116', 'order': '#ORD-000126', 'method': 'GCash', 'amount': '₱50.00', 'date': 'May 16, 2024, 08:46 AM', 'status': 'Pending'},
      {'id': '#TXN-902115', 'order': '#ORD-000125', 'method': 'Credit Card', 'amount': '₱100.00', 'date': 'May 15, 2024, 03:22 PM', 'status': 'Successful'},
      {'id': '#TXN-902114', 'order': '#ORD-000124', 'method': 'Cash', 'amount': '₱50.00', 'date': 'May 15, 2024, 01:10 PM', 'status': 'Cancelled'},
    ];

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Payment Transaction History Log', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: mockPayments.length,
              itemBuilder: (context, index) {
                final pay = mockPayments[index];
                final isSuccess = pay['status'] == 'Successful';
                final isPending = pay['status'] == 'Pending';
                final color = isSuccess ? Colors.green : (isPending ? Colors.orange : Colors.red);

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: color.withOpacity(0.08),
                      child: Icon(Icons.receipt_long_rounded, color: color),
                    ),
                    title: Text('${pay['id']} (${pay['method']})', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Order: ${pay['order']} • ${pay['date']}'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(pay['amount']!, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: color.withOpacity(0.15)),
                          ),
                          child: Text(
                            pay['status']!,
                            style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
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

  // TAB 6: ANALYTICS & REPORTS
  Widget _buildReportsTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Annual Refilling Analytics', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  const Text(
                    'Simulated Monthly Gallons Sold (Thousands)',
                    style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  // Render a simple horizontal bar chart
                  _buildBarReportRow('Jan - Mar', 0.65),
                  _buildBarReportRow('Apr - Jun', 0.88),
                  _buildBarReportRow('Jul - Sep', 0.72),
                  _buildBarReportRow('Oct - Dec', 0.94),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Helpers.showSnackBar(context, 'Exporting database report to CSV...'),
                  icon: const Icon(Icons.file_download_rounded),
                  label: const Text('Export CSV Sheet'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Helpers.showSnackBar(context, 'Preparing PDF print job...'),
                  icon: const Icon(Icons.print_rounded),
                  label: const Text('Print Report'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBarReportRow(String quarter, double pct) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(quarter, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 14,
                backgroundColor: Colors.grey.shade100,
                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text('${(pct * 100).toStringAsFixed(0)}K gal', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
          border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
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
                  CircleAvatar(backgroundColor: AppTheme.primaryColor, child: Icon(Icons.psychology_rounded, color: Colors.white)),
                  SizedBox(width: 12),
                  Text('AquaBot Dispatch Agent', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
                    alignment: isBot ? Alignment.centerLeft : Alignment.centerRight,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isBot ? const Color(0xFFF1F9FB) : AppTheme.primaryColor,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(12),
                          topRight: const Radius.circular(12),
                          bottomLeft: isBot ? Radius.zero : const Radius.circular(12),
                          bottomRight: isBot ? const Radius.circular(12) : Radius.zero,
                        ),
                        border: isBot ? Border.all(color: const Color(0xFFE2F0F3)) : null,
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
                    onPressed: () => _sendSupportMessage(_supportInputController.text),
                    backgroundColor: AppTheme.primaryColor,
                    mini: true,
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
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
                    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    filled: true,
                    fillColor: isDark ? AppTheme.darkSurface : Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
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
                  border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
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
                      DropdownMenuItem(value: 'Admin', child: Text('Administrators')),
                      DropdownMenuItem(value: 'Driver', child: Text('Drivers')),
                      DropdownMenuItem(value: 'Customer', child: Text('Customers')),
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
                        Icon(Icons.people_outline, size: 48, color: Colors.grey.shade500),
                        const SizedBox(height: 12),
                        Text('No accounts match your criteria', style: TextStyle(color: Colors.grey.shade500)),
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
                          border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0), width: 1.0),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor: _getRoleColor(user.role).withOpacity(0.12),
                            child: Icon(_getRoleIcon(user.role), color: _getRoleColor(user.role), size: 16),
                          ),
                          title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          subtitle: Text(user.email, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getRoleColor(user.role).withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: _getRoleColor(user.role).withOpacity(0.2), width: 1.0),
                                ),
                                child: Text(
                                  user.roleDisplayName,
                                  style: TextStyle(color: _getRoleColor(user.role), fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 8),
                              PopupMenuButton<UserRole>(
                                icon: const Icon(Icons.more_vert_rounded, size: 20),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                onSelected: (role) => _handleUpdateRole(user, role),
                                itemBuilder: (context) {
                                  return UserRole.values.map((role) {
                                    return PopupMenuItem<UserRole>(
                                      value: role,
                                      child: Text('Set to ${Helpers.capitalize(role.name)}', style: const TextStyle(fontSize: 13)),
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
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.grey.shade800),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.cloud_done_rounded, color: AppTheme.primaryColor, size: 22),
                    SizedBox(width: 12),
                    Text('Supabase Integration', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSettingRow(
                  'Connection Status',
                  _apiService.isSupabaseConfigured ? 'Connected (Active Database)' : 'Not Configured (Running Fallback Mock Mode)',
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
              border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.settings_suggest_rounded, color: AppTheme.accentColor, size: 22),
                    SizedBox(width: 12),
                    Text('UI & Control Settings', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Developer Diagnostic Mode', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Show warning popups and verbose console output for backend services.', style: TextStyle(fontSize: 11)),
                  trailing: Switch(
                    value: true,
                    onChanged: (val) {
                      Helpers.showSnackBar(context, 'Developer Diagnostic Mode Toggled!');
                    },
                    activeColor: AppTheme.primaryColor,
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
        Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w500)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isSuccess == null ? null : (isSuccess ? Colors.green : Colors.amber.shade700),
            ),
          ),
        ),
      ],
    );
  }
}

// Minimalist painter drawing road maps and houses for route mapping
class _FleetMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paintRoad = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 20
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    final paintRoadLines = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Draw road grid
    canvas.drawLine(Offset(20, size.height / 2), Offset(size.width - 20, size.height / 2), paintRoad);
    canvas.drawLine(Offset(size.width * 0.3, 20), Offset(size.width * 0.3, size.height - 20), paintRoad);
    canvas.drawLine(Offset(size.width * 0.7, 20), Offset(size.width * 0.7, size.height - 20), paintRoad);

    // Draw white center lines
    canvas.drawLine(Offset(20, size.height / 2), Offset(size.width - 20, size.height / 2), paintRoadLines);
    canvas.drawLine(Offset(size.width * 0.3, 20), Offset(size.width * 0.3, size.height - 20), paintRoadLines);
    canvas.drawLine(Offset(size.width * 0.7, 20), Offset(size.width * 0.7, size.height - 20), paintRoadLines);

    // Draw houses / delivery markers
    final paintHouse = Paint()..color = AppTheme.primaryColor.withOpacity(0.8);
    final paintSelected = Paint()..color = const Color(0xFF0284C7);

    // Draw houses as small rounded rectangles
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(size.width * 0.1, size.height * 0.2, 36, 28), const Radius.circular(4)), paintHouse);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(size.width * 0.45, size.height * 0.2, 36, 28), const Radius.circular(4)), paintHouse);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(size.width * 0.8, size.height * 0.65, 36, 28), const Radius.circular(4)), paintSelected);

    // Draw truck / vehicle markers
    final paintTruck = Paint()..color = const Color(0xFF10B981);
    canvas.drawCircle(Offset(size.width * 0.3, size.height * 0.5), 10, paintTruck);
    canvas.drawCircle(Offset(size.width * 0.7, size.height * 0.3), 10, paintTruck);

    // Text labels
    const textStyle = TextStyle(color: Colors.black54, fontSize: 8, fontWeight: FontWeight.bold);
    final textPainter = TextPainter(
      text: const TextSpan(text: 'Hub Center', style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(size.width * 0.3 + 12, size.height / 2 + 12));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
