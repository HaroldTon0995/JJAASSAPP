import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/helpers.dart';
import '../../../models/order_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/order_provider.dart';
import '../../../services/api_service.dart';
import '../../../services/ai_support_service.dart';
import '../../../widgets/water_widgets.dart';
import '../../../widgets/google_map_widget.dart';
import 'package:url_launcher/url_launcher.dart';
import 'driver_styles.dart';

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({super.key});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  int _selectedTab = 0;
  int _activeSidebarMenu = 0;

  // AI Chat States
  final List<Map<String, dynamic>> _supportMessages = [
    {
      'sender': 'AquaBot',
      'message': "Hello! I'm AquaBot 💧 How can I help you today?",
    },
  ];
  final TextEditingController _supportInputController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  bool _isChatLoading = false;

  // Settings controller
  final TextEditingController _plateNoController = TextEditingController(
    text: 'ABC-1234',
  );
  String _selectedVehicleType = 'Motorcycle with Rack';

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  @override
  void dispose() {
    _supportInputController.dispose();
    _chatScrollController.dispose();
    _plateNoController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _apiService.getDriverDashboardData();
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(
          context,
          'Failed to load driver data.',
          isError: true,
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _acceptDeliveryJob(OrderModel order) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final user = auth.currentUser;

    final success = await orderProvider.acceptJob(
      orderId: order.id,
      driverId: user?.id ?? '',
      driverName: user?.name ?? 'Driver',
    );

    if (success) {
      if (mounted) {
        setState(() {
          _selectedTab = 1; // Auto navigate to GPS Map Tab
          _activeSidebarMenu = 1;
        });
        Helpers.showSnackBar(
          context,
          'Job ${order.id} accepted! Navigate via GPS Deliveries Map.',
        );
      }
    } else {
      if (mounted) {
        Helpers.showSnackBar(
          context,
          'You currently have an active delivery job. Complete it first!',
          isError: true,
        );
      }
    }
  }

  void _completeActiveJob(OrderModel activeOrder) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final user = auth.currentUser;

    final success = await orderProvider.completeJob(
      orderId: activeOrder.id,
      driverId: user?.id ?? '',
    );

    if (success && mounted) {
      final payoutVal = activeOrder.totalAmount * 0.5;
      setState(() {
        _selectedTab = 0; // Go back to dashboard
        _activeSidebarMenu = 0;
      });
      Helpers.showSnackBar(
        context,
        'Delivery completed successfully! +₱${payoutVal.toStringAsFixed(2)} earnings added.',
      );
    }
  }

  void _sendSupportMessage(String text) async {
    if (text.trim().isEmpty) return;
    if (_isChatLoading) return; // Prevent multiple requests at once
    final userQuery = text.trim();

    setState(() {
      _supportMessages.add({'sender': 'Driver', 'message': userQuery});
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
        isDriver: true,
        isAdmin: false,
        userId: user?.id ?? '',
        userName: user?.name ?? 'Driver',
        orderProvider: orderProvider,
      );

      if (mounted) {
        setState(() {
          if (_supportMessages.isNotEmpty && _supportMessages.last['message'] == 'Thinking...') {
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
          if (_supportMessages.isNotEmpty && _supportMessages.last['message'] == 'Thinking...') {
            _supportMessages.removeLast();
          }
          _supportMessages.add({
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
                    '${auth.currentUser?.name ?? "Driver"}!',
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
                hintText: 'Search routes, orders...',
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
                (auth.currentUser?.name ?? 'D').substring(0, 1).toUpperCase(),
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
        return 'Driver Dispatch Dashboard';
      case 1:
        return 'Live GPS Navigation Map';
      case 2:
        return 'Trip Duty History';
      case 3:
        return 'AI Support Dispatch';
      case 4:
        return 'Vehicle & Profile Settings';
      default:
        return 'Driver Dashboard';
    }
  }

  Widget _buildSidebar(bool isDark, {bool isDrawer = false}) {
    final menuItems = [
      {'title': 'Dashboard', 'icon': Icons.home_rounded},
      {'title': 'Deliveries Map', 'icon': Icons.map_rounded},
      {'title': 'Duty History', 'icon': Icons.history_rounded},
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
                    'Efficient Log',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pure water, delivered fast.',
                    style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ),
          _SidebarItemTile(
            icon: Icons.logout_rounded,
            title: 'Log Out',
            isSelected: false,
            textColor: const Color(0xFFEF4444),
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
        return _buildDeliveriesMapTab(isDark);
      case 2:
        return _buildDutyHistoryTab(isDark);
      case 3:
        return _buildSupportTab(isDark);
      case 4:
        return _buildSettingsTab(isDark);
      default:
        return _buildOverviewTab(isDark, width);
    }
  }

  // TAB 0: DISPATCH DASHBOARD / OVERVIEW
  Widget _buildOverviewTab(bool isDark, double width) {
    final isDesktop = width >= 1100;
    final auth = Provider.of<AuthProvider>(context);
    final orderProvider = Provider.of<OrderProvider>(context);
    final user = auth.currentUser;
    final driverId = user?.id ?? '';
    final todaysEarnings = orderProvider.getDriverEarnings(driverId);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stat Cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  "Today's Income",
                  '₱${todaysEarnings.toStringAsFixed(2)}',
                  'Earning details',
                  Icons.payments_rounded,
                  const Color(0xFF10B981),
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
                  child: Column(children: [_buildJobsCard(isDark)]),
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
                _buildJobsCard(isDark),
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
    return DriverStatCard(
      title: title,
      value: value,
      subtitle: subtitle,
      icon: icon,
      color: color,
      isDark: isDark,
    );
  }

  Widget _buildJobsCard(bool isDark) {
    final auth = Provider.of<AuthProvider>(context);
    final orderProvider = Provider.of<OrderProvider>(context);
    final user = auth.currentUser;
    final driverId = user?.id ?? '';

    final availableJobs = orderProvider.getAvailableDriverJobs(driverId);
    final activeJob = orderProvider.getActiveDriverJob(driverId);

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: DriverDecorations.card(isDark: isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Available Job Invitations',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 16),
          if (availableJobs.isEmpty && activeJob == null)
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: Center(child: Text('No job invitations at the moment.')),
            )
          else ...[
            if (activeJob != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.directions_bike_rounded,
                      color: AppTheme.primaryColor,
                      size: 28,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Active Job: ${activeJob.id}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          Text(
                            'Customer: ${activeJob.customerName}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          Text(
                            'Dest: ${activeJob.deliveryAddress}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => setState(() {
                        _selectedTab = 1;
                        _activeSidebarMenu = 1;
                      }),
                      child: const Text(
                        'Go to Map',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: availableJobs.length,
              itemBuilder: (context, index) {
                final job = availableJobs[index];
                final payoutVal = job.totalAmount * 0.5;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Container(
                    padding: const EdgeInsets.all(16),
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
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(
                              alpha: 0.08,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.location_on_rounded,
                            color: AppTheme.primaryColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${job.customerName} (${job.id})',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                job.deliveryAddress,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF475569),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.secondaryColor.withValues(
                                    alpha: 0.08,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Items: ${job.itemsSummary} • Dist: ${job.distance}',
                                  style: const TextStyle(
                                    color: AppTheme.secondaryColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₱${payoutVal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Color(0xFF10B981),
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                backgroundColor: AppTheme.primaryColor,
                                textStyle: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onPressed: () => _acceptDeliveryJob(job),
                              child: const Text('Accept Job'),
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
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard(bool isDark) {
    final actions = [
      {
        'title': 'Map View',
        'icon': Icons.map_rounded,
        'color': const Color(0xFF0284C7),
        'tab': 1,
      },
      {
        'title': 'Driver Support',
        'icon': Icons.support_agent_rounded,
        'color': const Color(0xFF0EA5E9),
        'tab': 3,
      },
      {
        'title': 'Settings',
        'icon': Icons.settings_rounded,
        'color': const Color(0xFF10B981),
        'tab': 4,
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
                    controller: _supportInputController,
                    onSubmitted: (val) {
                      _sendSupportMessage(val);
                      setState(() {
                        _selectedTab = 3; // Route to support tab
                        _activeSidebarMenu = 3;
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
                    _sendSupportMessage(_supportInputController.text);
                    setState(() {
                      _selectedTab = 3;
                      _activeSidebarMenu = 3;
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

  // TAB 1: DELIVERIES MAP (Google Maps tracking)
  Widget _buildDeliveriesMapTab(bool isDark) {
    final auth = Provider.of<AuthProvider>(context);
    final orderProvider = Provider.of<OrderProvider>(context);
    final user = auth.currentUser;
    final driverId = user?.id ?? '';
    final activeJob = orderProvider.getActiveDriverJob(driverId);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (activeJob == null)
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.map_rounded, size: 48, color: Colors.grey),
                      SizedBox(height: 12),
                      Text(
                        'No active delivery job.',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        'Accept a job on the Dashboard to view route.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on_rounded,
                    color: AppTheme.primaryColor,
                    size: 28,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Customer: ${activeJob.customerName} (${activeJob.id})',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Address: ${activeJob.deliveryAddress}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        Text(
                          'Items: ${activeJob.itemsSummary}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        if (activeJob.deliveryNote != null)
                          Container(
                            margin: const EdgeInsets.only(top: 6),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFF59E0B),
                              ),
                            ),
                            child: Text(
                              '📝 Customer Note: ${activeJob.deliveryNote}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF78350F),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () async {
                          final String url;
                          if (activeJob.latitude != null &&
                              activeJob.longitude != null) {
                            url =
                                'https://www.google.com/maps/dir/?api=1&destination=${activeJob.latitude},${activeJob.longitude}';
                          } else {
                            final query =
                                Uri.encodeComponent(activeJob.deliveryAddress);
                            url =
                                'https://www.google.com/maps/search/?api=1&query=$query';
                          }
                          final uri = Uri.parse(url);
                          final canLaunch = await canLaunchUrl(uri);
                          if (!mounted) return;
                          if (canLaunch) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          } else {
                            Helpers.showSnackBar(context, 'Could not launch Google Maps.', isError: true);
                          }
                        },
                        icon: const Icon(Icons.navigation_rounded, size: 16),
                        label: const Text('Navigate'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () => _completeActiveJob(activeJob),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        child: const Text('Delivered'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: GoogleMapWidget(
                    destinationLat: activeJob.latitude,
                    destinationLng: activeJob.longitude,
                    destinationAddress: activeJob.deliveryAddress,
                    isDriverView: true,
                    orderId: activeJob.id,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // TAB 2: TRIP DUTY HISTORY
  Widget _buildDutyHistoryTab(bool isDark) {
    final auth = Provider.of<AuthProvider>(context);
    final orderProvider = Provider.of<OrderProvider>(context);
    final user = auth.currentUser;
    final driverId = user?.id ?? '';
    final completedJobs = orderProvider.getDriverCompletedJobs(driverId);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Trip Duty Log Sheet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: completedJobs.isEmpty
                ? const Center(child: Text('No trips completed today.'))
                : ListView.builder(
                    itemCount: completedJobs.length,
                    itemBuilder: (context, index) {
                      final job = completedJobs[index];
                      final payoutVal = job.totalAmount * 0.5;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.white,
                            child: Icon(
                              Icons.check_rounded,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          title: Text(
                            '${job.customerName} (${job.id})',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Dest: ${job.deliveryAddress} • Items: ${job.itemsSummary}',
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '₱${payoutVal.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Color(0xFF10B981),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                job.completedAt?.toString().split('.')[0] ??
                                    'Completed',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
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

  // TAB 4: AI SUPPORT DESK (Full chat interface)
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
                    'AquaBot Driver Dispatch Support',
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
                        hintText: 'Type dispatch query...',
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

  // TAB 5: SETTINGS
  InputDecoration _boxedDecoration(String label) {
    OutlineInputBorder border(Color color, [double width = 1.2]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF475569)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: border(const Color(0xFFCBD5E1)),
      enabledBorder: border(const Color(0xFFCBD5E1)),
      focusedBorder: border(AppTheme.primaryColor, 2),
    );
  }

  Widget _buildSettingsTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vehicle Profile Settings',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _selectedVehicleType,
                  isExpanded: true,
                  decoration: _boxedDecoration('Registered Vehicle Type'),
                  items: const [
                    DropdownMenuItem(
                      value: 'Motorcycle with Rack',
                      child: Text(
                        'Motorcycle with Rack',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'Sidecar / Tricycle',
                      child: Text(
                        'Sidecar / Tricycle',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'Delivery Truck',
                      child: Text(
                        'Delivery Truck',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedVehicleType = val);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _plateNoController,
                  style: const TextStyle(color: Color(0xFF0F172A)),
                  decoration: _boxedDecoration('Plate Number'),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Helpers.showSnackBar(
                      context,
                      'Vehicle registration updated.',
                    );
                  },
                  child: const Text('Save Details'),
                ),
              ],
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
