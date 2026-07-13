import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  Map<String, dynamic> _data = {};

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final data = await _apiService.getAdminDashboardData();
      setState(() {
        _data = data;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(context, 'Failed to load system reports.', isError: true);
        setState(() {
          _isLoading = false;
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Console'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Stats',
            onPressed: _loadDashboardData,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'System Stats & Revenue',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),

                    // Grid stats
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.3,
                      children: [
                        _buildAdminStatCard(
                          'Total Accounts',
                          '${_data['totalUsers'] ?? 0}',
                          Icons.people_alt_rounded,
                          AppTheme.primaryColor,
                        ),
                        _buildAdminStatCard(
                          'Active Drivers',
                          '${_data['activeDrivers'] ?? 0}',
                          Icons.electric_scooter_rounded,
                          AppTheme.accentColor,
                        ),
                        _buildAdminStatCard(
                          'Active Customers',
                          '${_data['activeCustomers'] ?? 0}',
                          Icons.shopping_bag_rounded,
                          AppTheme.secondaryColor,
                        ),
                        _buildAdminStatCard(
                          'Daily Income',
                          '\$${(_data['dailyRevenue'] as double?)?.toStringAsFixed(0) ?? "0"}',
                          Icons.payments_rounded,
                          Colors.green,
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // System Alerts Section
                    Text(
                      'Recent Logs & Alerts',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),

                    ...((_data['systemAlerts'] as List? ?? []).map((alert) {
                      final isWarning = alert['type'] == 'Warning';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: Icon(
                            isWarning ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
                            color: isWarning ? Colors.orange : Colors.blue,
                            size: 28,
                          ),
                          title: Text(
                            alert['message'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          subtitle: Text(alert['time'] ?? ''),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: (isWarning ? Colors.orange : Colors.blue).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              alert['type'] ?? '',
                              style: TextStyle(
                                color: isWarning ? Colors.orange : Colors.blue,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList()),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildAdminStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 24),
                Text(
                  title,
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
