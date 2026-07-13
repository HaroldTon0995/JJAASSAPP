import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/app_constants.dart';

class ApiService {
  final _random = Random();

  bool get _isSupabaseConfigured => (AppConstants.supabaseUrl != 'YOUR_SUPABASE_PROJECT_URL' &&
          AppConstants.supabaseAnonKey != 'YOUR_SUPABASE_PROJECT_ANON_KEY');

  // Mock fetching dashboard stats for customers
  Future<Map<String, dynamic>> getCustomerDashboardData() async {
    await Future.delayed(const Duration(milliseconds: 800));
    return {
      'activeOrders': _random.nextInt(3),
      'pastDeliveries': 12 + _random.nextInt(10),
      'rewardPoints': 250 + _random.nextInt(100),
      'recentTransactions': [
        {'id': 'TX_1001', 'amount': '\$24.50', 'status': 'Delivered', 'date': 'Today'},
        {'id': 'TX_0989', 'amount': '\$12.80', 'status': 'Delivered', 'date': 'Yesterday'},
      ],
    };
  }

  // Mock fetching driver dashboard stats
  Future<Map<String, dynamic>> getDriverDashboardData() async {
    await Future.delayed(const Duration(milliseconds: 900));
    return {
      'todaysEarnings': 120.0 + _random.nextInt(80),
      'completedTrips': 5 + _random.nextInt(5),
      'rating': 4.7 + (_random.nextDouble() * 0.3),
      'onlineStatus': true,
      'availableJobs': [
        {'id': 'JOB_223', 'distance': '2.1 miles', 'payout': '\$14.50', 'destination': 'Downtown Center'},
        {'id': 'JOB_224', 'distance': '4.5 miles', 'payout': '\$22.00', 'destination': 'Uptown Galleria'},
      ],
    };
  }

  // Fetching system reports for admin - queries Supabase if available
  Future<Map<String, dynamic>> getAdminDashboardData() async {
    int totalUsersCount = 1420 + _random.nextInt(50);
    int activeDriversCount = 48 + _random.nextInt(12);
    int activeCustomersCount = 682 + _random.nextInt(30);

    if (_isSupabaseConfigured) {
      try {
        final client = Supabase.instance.client;
        
        // Query user tables and check length
        final usersRes = await client.from('profiles').select();
        totalUsersCount = usersRes.length;
        
        final driversRes = await client.from('profiles').select().eq('role', 'driver');
        activeDriversCount = driversRes.length;
        
        final customersRes = await client.from('profiles').select().eq('role', 'customer');
        activeCustomersCount = customersRes.length;
      } catch (e) {
        // Fallback silently to mock numbers if query fails
      }
    }

    await Future.delayed(const Duration(milliseconds: 1000));
    return {
      'totalUsers': totalUsersCount,
      'activeDrivers': activeDriversCount,
      'activeCustomers': activeCustomersCount,
      'dailyRevenue': 4850.50 + _random.nextInt(1200),
      'systemAlerts': [
        {'type': 'Warning', 'message': 'High driver demand in sector B', 'time': '10 mins ago'},
        {'type': 'Info', 'message': 'System database backups completed', 'time': '1 hr ago'},
      ],
    };
  }
}
