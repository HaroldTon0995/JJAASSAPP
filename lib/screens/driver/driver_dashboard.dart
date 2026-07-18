import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/water_widgets.dart';

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({super.key});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  bool _isOnline = true;
  int _selectedTab = 0; 
  int _activeSidebarMenu = 0;

  // Fully interactive mock data state variables
  late List<Map<String, dynamic>> _availableJobs;
  late List<Map<String, dynamic>> _completedTrips;
  Map<String, dynamic>? _activeAcceptedJob;
  double _todaysEarnings = 450.00;
  double _driverRating = 4.85;

  // AI Chat States
  final List<Map<String, dynamic>> _supportMessages = [
    {'sender': 'AquaBot', 'message': "Hello! I'm AquaBot 💧 How can I help you today?"},
  ];
  final TextEditingController _supportInputController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();

  // Settings controller
  final TextEditingController _plateNoController = TextEditingController(text: 'ABC-1234');
  String _selectedVehicleType = 'Motorcycle with Rack';

  @override
  void initState() {
    super.initState();
    _initMockData();
    _loadDashboardData();
  }

  @override
  void dispose() {
    _supportInputController.dispose();
    _chatScrollController.dispose();
    _plateNoController.dispose();
    super.dispose();
  }

  void _initMockData() {
    _availableJobs = [
      {'id': '#JOB-102', 'customer': 'Pedro Reyes', 'destination': 'Brgy. Mabini, House 14', 'distance': '1.2 km', 'payout': '₱50.00', 'items': '1 x 19L Purified'},
      {'id': '#JOB-103', 'customer': 'Juan Dela Cruz', 'destination': 'Brgy. San Isidro, Apt B', 'distance': '2.8 km', 'payout': '₱80.00', 'items': '2 x 19L Purified'},
      {'id': '#JOB-104', 'customer': 'Anna Garcia', 'destination': 'Brgy. San Vicente, Lot 2', 'distance': '3.5 km', 'payout': '₱100.00', 'items': '2 x 19L Alkaline'},
    ];

    _completedTrips = [
      {'id': '#TRIP-091', 'customer': 'Maria Santos', 'destination': 'Brgy. Poblacion, Road 2', 'distance': '1.5 km', 'payout': '₱60.00', 'time': '09:15 AM'},
      {'id': '#TRIP-090', 'customer': 'Lito Lapid', 'destination': 'Brgy. San Isidro, St 4', 'distance': '2.1 km', 'payout': '₱70.00', 'time': 'Yesterday'},
    ];
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final data = await _apiService.getDriverDashboardData();
      if (mounted) {
        setState(() {
          _todaysEarnings = (data['todaysEarnings'] as double?) ?? _todaysEarnings;
          _driverRating = (data['rating'] as double?) ?? _driverRating;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(context, 'Failed to load driver data.', isError: true);
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _acceptDeliveryJob(Map<String, dynamic> job) {
    if (_activeAcceptedJob != null) {
      Helpers.showSnackBar(context, 'You currently have an active delivery job. Complete it first!', isError: true);
      return;
    }

    setState(() {
      _activeAcceptedJob = job;
      _availableJobs.removeWhere((item) => item['id'] == job['id']);
      _selectedTab = 1; // Auto navigate to GPS Map Tab
      _activeSidebarMenu = 1;
    });

    Helpers.showSnackBar(context, 'Job ${job['id']} accepted! Navigate via GPS Deliveries Map.');
  }

  void _completeActiveJob() {
    if (_activeAcceptedJob == null) return;
    final completedJob = _activeAcceptedJob!;
    final double payoutVal = double.tryParse(completedJob['payout']!.replaceAll('₱', '')) ?? 0.00;

    setState(() {
      _completedTrips.insert(0, {
        'id': completedJob['id'].replaceAll('JOB', 'TRIP'),
        'customer': completedJob['customer'],
        'destination': completedJob['destination'],
        'distance': completedJob['distance'],
        'payout': completedJob['payout'],
        'time': 'Just Now',
      });
      _todaysEarnings += payoutVal;
      _activeAcceptedJob = null;
      _selectedTab = 0; // Go back to dashboard
      _activeSidebarMenu = 0;
    });

    Helpers.showSnackBar(context, 'Delivery completed successfully! +₱${payoutVal.toStringAsFixed(2)} added.');
  }

  void _cashOutEarnings() {
    if (_todaysEarnings <= 0) {
      Helpers.showSnackBar(context, 'No earnings balance to cash out.', isError: true);
      return;
    }

    final cashOutVal = _todaysEarnings;
    setState(() {
      _todaysEarnings = 0.00;
    });

    Helpers.showSnackBar(context, 'Successfully cashed out ₱${cashOutVal.toStringAsFixed(2)} to your GCash account!');
  }

  void _sendSupportMessage(String text) {
    if (text.trim().isEmpty) return;
    setState(() {
      _supportMessages.add({'sender': 'Driver', 'message': text});
      _supportInputController.clear();

      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() {
            _supportMessages.add({
              'sender': 'AquaBot',
              'message': 'Received! AquaBot dispatch will coordinate support for: "$text"'
            });
          });
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
              title: Text(_getTabTitle(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
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
    final auth = Provider.of<AuthProvider>(context);
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
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
              ),
              Row(
                children: [
                  const Text('Welcome back, ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  Text(
                    '${auth.currentUser?.name ?? "Driver"}!',
                    style: const TextStyle(fontSize: 12, color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
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
                prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade400, size: 18),
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
            icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFF64748B)),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF64748B)),
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
            child: CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.primaryColor.withOpacity(0.12),
              child: Text(
                (auth.currentUser?.name ?? 'D').substring(0, 1).toUpperCase(),
                style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
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
        return 'Driver Earnings Portal';
      case 4:
        return 'AI Support Dispatch';
      case 5:
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
      {'title': 'My Earnings', 'icon': Icons.payments_rounded},
      {'title': 'AI Chat Support', 'icon': Icons.chat_rounded},
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
                  children: [
                    const Text(
                      'JJAASS',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.primaryColor, letterSpacing: 0.5),
                    ),
                    Text(
                      'Water Market',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
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
                    'Efficient Log',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppTheme.primaryColor),
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
        return _buildEarningsTab(isDark);
      case 4:
        return _buildSupportTab(isDark);
      case 5:
        return _buildSettingsTab(isDark);
      default:
        return _buildOverviewTab(isDark, width);
    }
  }

  // TAB 0: DISPATCH DASHBOARD / OVERVIEW
  Widget _buildOverviewTab(bool isDark, double width) {
    final isDesktop = width >= 1100;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Duty Switch Header Banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _isOnline
                    ? [const Color(0xFF009CA6), const Color(0xFF0EA5E9)]
                    : [Colors.red.shade700, Colors.red.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: (_isOnline ? const Color(0xFF009CA6) : Colors.red).withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.white.withOpacity(0.18),
                  child: const Icon(Icons.drive_eta_rounded, size: 28, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Delivery Duty Status',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _isOnline ? 'Online - Receiving delivery jobs' : 'Offline - Resting',
                        style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _isOnline,
                  activeColor: Colors.white,
                  activeTrackColor: const Color(0xFF10B981),
                  inactiveThumbColor: Colors.white70,
                  inactiveTrackColor: Colors.black26,
                  onChanged: (value) {
                    setState(() {
                      _isOnline = value;
                    });
                    Helpers.showSnackBar(
                      context,
                      _isOnline ? 'You are now Online and ready!' : 'You are now Offline.',
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Stat Cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  "Today's Income",
                  '₱${_todaysEarnings.toStringAsFixed(2)}',
                  'Earning details',
                  Icons.payments_rounded,
                  const Color(0xFF10B981),
                  isDark,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Driver Rating',
                  '${_driverRating.toStringAsFixed(2)} ★',
                  'Customer rating',
                  Icons.star_rounded,
                  const Color(0xFFF59E0B),
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
                  child: Column(
                    children: [
                      _buildJobsCard(isDark),
                    ],
                  ),
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
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
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
            child: Icon(icon, color: color, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildJobsCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Available Job Invitations',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 16),
          if (!_isOnline)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.02) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
              ),
              child: const Center(
                child: Text(
                  'Go Online to view job invitations.',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                ),
              ),
            )
          else if (_availableJobs.isEmpty && _activeAcceptedJob == null)
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: Center(child: Text('No job invitations at the moment.')),
            )
          else ...[
            if (_activeAcceptedJob != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.directions_bike_rounded, color: AppTheme.primaryColor, size: 28),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Active Deliver Job in Progress', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                          Text('Dest: ${_activeAcceptedJob!['destination']}', style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => setState(() {
                        _selectedTab = 1;
                        _activeSidebarMenu = 1;
                      }),
                      child: const Text('Go to Map', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _availableJobs.length,
              itemBuilder: (context, index) {
                final job = _availableJobs[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.02) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.location_on_rounded, color: AppTheme.primaryColor, size: 24),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                job['destination'] ?? '',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.secondaryColor.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Distance: ${job['distance'] ?? ""}',
                                  style: const TextStyle(color: AppTheme.secondaryColor, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              job['payout'] ?? '',
                              style: const TextStyle(
                                color: Color(0xFF10B981),
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                backgroundColor: AppTheme.primaryColor,
                                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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
      {'title': 'Map View', 'icon': Icons.map_rounded, 'color': const Color(0xFF009CA6), 'tab': 1},
      {'title': 'Earnings Log', 'icon': Icons.list_alt_rounded, 'color': const Color(0xFF0284C7), 'tab': 3},
      {'title': 'Driver Support', 'icon': Icons.support_agent_rounded, 'color': const Color(0xFF0EA5E9), 'tab': 4},
      {'title': 'Settings', 'icon': Icons.settings_rounded, 'color': const Color(0xFF10B981), 'tab': 5},
    ];

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
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
                    color: (act['color'] as Color).withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: (act['color'] as Color).withOpacity(0.1)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(act['icon'] as IconData, color: act['color'] as Color, size: 22),
                      const SizedBox(height: 6),
                      Text(
                        act['title'] as String,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
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
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.psychology_rounded, color: AppTheme.primaryColor, size: 20),
              SizedBox(width: 8),
              Text(
                'AI Chat Support',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F9FB),
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
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Hello! I\'m AquaBot 💧 How can I help you today?',
                        style: TextStyle(fontSize: 11, color: Color(0xFF475569), height: 1.3),
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
                        _selectedTab = 4; // Route to support tab
                        _activeSidebarMenu = 4;
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
                      _selectedTab = 4;
                      _activeSidebarMenu = 4;
                    });
                  },
                  icon: const Icon(Icons.send_rounded, size: 14, color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // TAB 1: DELIVERIES MAP (Mock GPS routing)
  Widget _buildDeliveriesMapTab(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_activeAcceptedJob == null)
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.map_rounded, size: 48, color: Colors.grey),
                      SizedBox(height: 12),
                      Text('No active delivery job.', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                      Text('Accept a job on the Dashboard to view route.', style: TextStyle(fontSize: 12, color: Colors.grey)),
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
                border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on_rounded, color: AppTheme.primaryColor, size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Customer: ${_activeAcceptedJob!['customer']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('Address: ${_activeAcceptedJob!['destination']}', style: const TextStyle(fontSize: 12)),
                        Text('Items: ${_activeAcceptedJob!['items']}', style: const TextStyle(fontSize: 12, color: AppTheme.primaryColor)),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _completeActiveJob,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                    child: const Text('Mark as Delivered'),
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
                  border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    children: [
                      // Render a simulated GPS map route
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _GPSMapRoutePainter(),
                        ),
                      ),
                      const Positioned(
                        left: 20,
                        top: 20,
                        child: Card(
                          color: Colors.black87,
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            child: Text('GPS Status: Calibrated (Accuracy 3m)', style: TextStyle(color: Colors.white, fontSize: 10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ]
        ],
      ),
    );
  }

  // TAB 2: TRIP DUTY HISTORY
  Widget _buildDutyHistoryTab(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Trip Duty Log Sheet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: _completedTrips.isEmpty
                ? const Center(child: Text('No trips completed today.'))
                : ListView.builder(
                    itemCount: _completedTrips.length,
                    itemBuilder: (context, index) {
                      final trip = _completedTrips[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFECF8FA),
                            child: Icon(Icons.check_rounded, color: AppTheme.primaryColor),
                          ),
                          title: Text(trip['customer'] ?? 'Unknown Customer', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Dest: ${trip['destination']} • Dist: ${trip['distance']}'),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(trip['payout'] ?? '', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w900, fontSize: 14)),
                              const SizedBox(height: 4),
                              Text(trip['time'] ?? '', style: const TextStyle(fontSize: 10, color: Colors.grey)),
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

  // TAB 3: MY EARNINGS PORTAL
  Widget _buildEarningsTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF009CA6), Color(0xFF0284C7)]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Withdrawable Cash Balance', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('₱${_todaysEarnings.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                  ],
                ),
                ElevatedButton(
                  onPressed: _cashOutEarnings,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  child: const Text('Cash Out (GCash)', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('Earnings Growth Metric', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  const Text('Weekly trip earnings chart', style: TextStyle(color: Colors.grey, fontSize: 11)),
                  const SizedBox(height: 20),
                  _buildEarningMetricRow('Monday', 0.65, '₱450.00'),
                  _buildEarningMetricRow('Tuesday', 0.32, '₱220.00'),
                  _buildEarningMetricRow('Wednesday', 0.85, '₱590.00'),
                  _buildEarningMetricRow('Thursday (Today)', 0.50, '₱${_todaysEarnings.toStringAsFixed(0)}'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarningMetricRow(String day, double pct, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(day, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 12,
                backgroundColor: Colors.grey.shade100,
                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(val, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
                  Text('AquaBot Driver Dispatch Support', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
                        hintText: 'Type dispatch query...',
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

  // TAB 5: SETTINGS
  Widget _buildSettingsTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Vehicle Profile Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                DropdownButtonFormField<String>(
                  value: _selectedVehicleType,
                  decoration: const InputDecoration(labelText: 'Registered Vehicle Type'),
                  items: const [
                    DropdownMenuItem(value: 'Motorcycle with Rack', child: Text('Motorcycle with Rack')),
                    DropdownMenuItem(value: 'Sidecar / Tricycle', child: Text('Sidecar / Tricycle')),
                    DropdownMenuItem(value: 'Delivery Truck', child: Text('Delivery Truck')),
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
                  decoration: const InputDecoration(labelText: 'Plate Number'),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Helpers.showSnackBar(context, 'Vehicle registration updated.');
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

// Draw a stylized GPS map tracking route lines
class _GPSMapRoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paintRoad = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 24
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final paintRoute = Paint()
      ..color = const Color(0xFF0284C7)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final paintRoadLines = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Draw main grid path
    final roadPath = Path()
      ..moveTo(20, size.height * 0.8)
      ..lineTo(size.width * 0.4, size.height * 0.8)
      ..lineTo(size.width * 0.4, size.height * 0.3)
      ..lineTo(size.width - 20, size.height * 0.3);

    final crossRoad = Path()
      ..moveTo(size.width * 0.1, size.height * 0.3)
      ..lineTo(size.width * 0.4, size.height * 0.3)
      ..moveTo(size.width * 0.4, size.height * 0.8)
      ..lineTo(size.width * 0.8, size.height * 0.8);

    canvas.drawPath(roadPath, paintRoad);
    canvas.drawPath(crossRoad, paintRoad);

    // Draw white center lines
    canvas.drawPath(roadPath, paintRoadLines);
    canvas.drawPath(crossRoad, paintRoadLines);

    // Draw active GPS route
    final routePath = Path()
      ..moveTo(50, size.height * 0.8)
      ..lineTo(size.width * 0.4, size.height * 0.8)
      ..lineTo(size.width * 0.4, size.height * 0.3)
      ..lineTo(size.width * 0.75, size.height * 0.3);
    canvas.drawPath(routePath, paintRoute);

    // Draw station hub marker
    final paintHub = Paint()..color = AppTheme.primaryColor;
    canvas.drawCircle(Offset(50, size.height * 0.8), 12, paintHub);

    // Draw destination pin
    final paintPin = Paint()..color = const Color(0xFFEF4444);
    canvas.drawCircle(Offset(size.width * 0.75, size.height * 0.3), 12, paintPin);

    // Draw truck position
    final paintTruck = Paint()..color = const Color(0xFF10B981);
    canvas.drawCircle(Offset(size.width * 0.4, size.height * 0.6), 8, paintTruck);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
