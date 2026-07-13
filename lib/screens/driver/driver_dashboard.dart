import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({super.key});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  bool _isOnline = true;
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
      final data = await _apiService.getDriverDashboardData();
      setState(() {
        _data = data;
        _isOnline = data['onlineStatus'] ?? true;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(context, 'Failed to load driver data.', isError: true);
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
    final auth = Provider.of<AuthProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Portal'),
        actions: [
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
                    // Driver Info & Toggle Status Banner
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _isOnline ? Colors.green.shade700 : Colors.red.shade700,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: (_isOnline ? Colors.green : Colors.red).withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 30,
                                backgroundColor: Colors.white.withOpacity(0.2),
                                child: const Icon(Icons.drive_eta_rounded, size: 36, color: Colors.white),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      auth.currentUser?.name ?? "Driver",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _isOnline ? 'Online - Receiving Rides' : 'Offline - Rest mode',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(color: Colors.white24, height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Toggles Duty State:',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                              ),
                              Switch(
                                value: _isOnline,
                                activeColor: Colors.white,
                                activeTrackColor: Colors.green.shade400,
                                inactiveThumbColor: Colors.white,
                                inactiveTrackColor: Colors.grey.shade400,
                                onChanged: (value) {
                                  setState(() {
                                    _isOnline = value;
                                  });
                                  Helpers.showSnackBar(
                                    context,
                                    _isOnline ? 'You are now Online!' : 'You are now Offline.',
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Driver statistics rows
                    Row(
                      children: [
                        Expanded(
                          child: _buildDriverStatCard(
                            context,
                            "Today's Income",
                            '\$${(_data['todaysEarnings'] as double?)?.toStringAsFixed(2) ?? "0.00"}',
                            Icons.monetization_on_rounded,
                            Colors.amber.shade700,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildDriverStatCard(
                            context,
                            'Driver Rating',
                            '${(_data['rating'] as double?)?.toStringAsFixed(2) ?? "5.00"} ★',
                            Icons.star_half_rounded,
                            Colors.blueAccent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Available Jobs
                    Text(
                      'Available Job Invitations',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (!_isOnline)
                      Card(
                        color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                        child: const Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Center(
                            child: Text(
                              'Go Online to view job invitations.',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),
                        ),
                      )
                    else
                      ...((_data['availableJobs'] as List? ?? []).map((job) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.location_on_rounded, color: AppTheme.primaryColor),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        job['destination'] ?? '',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      const SizedBox(height: 4),
                                      Text('Distance: ${job['distance'] ?? ""}'),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      job['payout'] ?? '',
                                      style: const TextStyle(
                                        color: Colors.greenAccent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        backgroundColor: AppTheme.primaryColor,
                                      ),
                                      onPressed: () {
                                        Helpers.showSnackBar(context, 'Ride Accepted!');
                                      },
                                      child: const Text('Accept', style: TextStyle(fontSize: 12)),
                                    ),
                                  ],
                                ),
                              ],
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

  Widget _buildDriverStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(icon, color: color, size: 20),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
