import 'package:flutter/material.dart';
import '../../screens/splash/splash_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/register_screen.dart';
import '../../screens/customer/customer_dashboard.dart';
import '../../screens/driver/driver_dashboard.dart';
import '../../screens/admin/admin_dashboard.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String customerDashboard = '/customer';
  static const String driverDashboard = '/driver';
  static const String adminDashboard = '/admin';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case register:
        return MaterialPageRoute(builder: (_) => const RegisterScreen());
      case customerDashboard:
        return MaterialPageRoute(builder: (_) => const CustomerDashboard());
      case driverDashboard:
        return MaterialPageRoute(builder: (_) => const DriverDashboard());
      case adminDashboard:
        return MaterialPageRoute(builder: (_) => const AdminDashboard());
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
    }
  }
}
