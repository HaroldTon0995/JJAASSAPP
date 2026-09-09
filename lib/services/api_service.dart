import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/app_constants.dart';
import '../models/user_model.dart';

class ApiService {
  final _random = Random();

  bool get isSupabaseConfigured => (AppConstants.supabaseUrl != 'YOUR_SUPABASE_PROJECT_URL' &&
          AppConstants.supabaseAnonKey != 'YOUR_SUPABASE_PROJECT_ANON_KEY');

  // Dynamic registered users list for local operations when Supabase is not configured
  static final List<UserModel> _registeredUsersList = [];

  // Expose static helper to add new users registered locally
  static void addMockUser(UserModel user) {
    final index = _registeredUsersList.indexWhere((u) => u.id == user.id || u.email.toLowerCase() == user.email.toLowerCase());
    if (index != -1) {
      _registeredUsersList[index] = user;
    } else {
      _registeredUsersList.add(user);
    }
  }

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
    int totalUsersCount = _registeredUsersList.length;
    int activeDriversCount = _registeredUsersList.where((u) => u.role == UserRole.driver).length;
    int activeCustomersCount = _registeredUsersList.where((u) => u.role == UserRole.customer).length;

    if (isSupabaseConfigured) {
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
        // Fallback silently if query fails
      }
    }

    await Future.delayed(const Duration(milliseconds: 1000));
    return {
      'totalUsers': totalUsersCount,
      'activeDrivers': activeDriversCount,
      'activeCustomers': activeCustomersCount,
      'dailyRevenue': 4850.50 + _random.nextInt(1200),
      'systemAlerts': [
        {'type': 'Warning', 'message': 'High driver demand in Sector B', 'time': '10 mins ago'},
        {'type': 'Info', 'message': 'System database backups completed', 'time': '1 hr ago'},
        {'type': 'Warning', 'message': 'High latency on authentication endpoint', 'time': '3 hrs ago'},
        {'type': 'Info', 'message': 'New driver registration pending approval', 'time': '4 hrs ago'},
      ],
    };
  }

  // Fetch list of users for administration
  Future<List<UserModel>> getAdminUsers() async {
    if (isSupabaseConfigured) {
      try {
        final client = Supabase.instance.client;
        final res = await client.from('profiles').select();
        return (res as List).map((u) => UserModel.fromJson(u as Map<String, dynamic>)).toList();
      } catch (e) {
        // Fallback silently if query fails
      }
    }
    await Future.delayed(AppConstants.apiMockDelay);
    return List.from(_registeredUsersList);
  }

  // Update a user role
  Future<bool> updateUserRole(String userId, UserRole role) async {
    if (isSupabaseConfigured) {
      try {
        final client = Supabase.instance.client;
        await client.from('profiles').update({'role': role.name}).eq('id', userId);
        return true;
      } catch (e) {
        // Fallback silently if query fails
      }
    }
    await Future.delayed(AppConstants.apiMockDelay);
    final index = _registeredUsersList.indexWhere((u) => u.id == userId);
    if (index != -1) {
      final oldUser = _registeredUsersList[index];
      _registeredUsersList[index] = UserModel(
        id: oldUser.id,
        name: oldUser.name,
        email: oldUser.email,
        role: role,
      );
      return true;
    }
    return false;
  }
}
