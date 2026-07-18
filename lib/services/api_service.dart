import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/app_constants.dart';
import '../models/user_model.dart';

class ApiService {
  final _random = Random();

  bool get isSupabaseConfigured => (AppConstants.supabaseUrl != 'YOUR_SUPABASE_PROJECT_URL' &&
          AppConstants.supabaseAnonKey != 'YOUR_SUPABASE_PROJECT_ANON_KEY');

  // Stateful mock user list for local operations when Supabase is not configured
  static final List<UserModel> _mockUsersList = [
    UserModel(id: 'usr_1', name: 'Alexander Pierce', email: 'alex.pierce@example.com', role: UserRole.admin),
    UserModel(id: 'usr_2', name: 'Jane Doe', email: 'jane.doe@example.com', role: UserRole.driver),
    UserModel(id: 'usr_3', name: 'John Smith', email: 'john.smith@example.com', role: UserRole.customer),
    UserModel(id: 'usr_4', name: 'Emily Watson', email: 'emily.w@example.com', role: UserRole.customer),
    UserModel(id: 'usr_5', name: 'Michael Corleone', email: 'michael.c@example.com', role: UserRole.driver),
    UserModel(id: 'usr_6', name: 'Sarah Connor', email: 'sarah@resistance.net', role: UserRole.customer),
    UserModel(id: 'usr_7', name: 'Bruce Wayne', email: 'batman@gotham.city', role: UserRole.admin),
    UserModel(id: 'usr_8', name: 'Clark Kent', email: 'superman@metropolis.com', role: UserRole.driver),
  ];

  // Expose static helper to add new users registered locally (mock database synchronization)
  static void addMockUser(UserModel user) {
    if (!_mockUsersList.any((u) => u.id == user.id || u.email.toLowerCase() == user.email.toLowerCase())) {
      _mockUsersList.add(user);
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
    int totalUsersCount = _mockUsersList.length;
    int activeDriversCount = _mockUsersList.where((u) => u.role == UserRole.driver).length;
    int activeCustomersCount = _mockUsersList.where((u) => u.role == UserRole.customer).length;

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
    return List.from(_mockUsersList);
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
    final index = _mockUsersList.indexWhere((u) => u.id == userId);
    if (index != -1) {
      final oldUser = _mockUsersList[index];
      _mockUsersList[index] = UserModel(
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
