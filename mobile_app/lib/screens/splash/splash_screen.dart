import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/water_widgets.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNextScreen();
  }

  Future<void> _navigateToNextScreen() async {
    await Future.delayed(AppConstants.splashDelay);
    if (!mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isLoggedIn = await authProvider.checkSession();
    if (!mounted) return;

    if (isLoggedIn) {
      final role = authProvider.currentUser?.role;
      _routeToDashboard(role);
    } else {
      Navigator.of(context).pushReplacementNamed(AppRoutes.login);
    }
  }

  Future<void> _routeToDashboard(UserRole? role) async {
    if (!mounted) return;
    if (role == null) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.login);
      return;
    }

    switch (role) {
      case UserRole.customer:
        Navigator.of(context).pushReplacementNamed(AppRoutes.customerDashboard);
        break;
      case UserRole.driver:
        Navigator.of(context).pushReplacementNamed(AppRoutes.driverDashboard);
        break;
      case UserRole.admin:
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        await authProvider.logout();
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed(AppRoutes.login);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.navyColor, // Deep Navy (#0F2B5C)
              AppTheme.primaryColor, // Rich Water Blue (#1D63B8)
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Opacity(
                  opacity: value,
                  child: child,
                ),
              );
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.secondaryColor.withValues(alpha: 0.5),
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.22),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const WaterDropletLogo(size: 96),
                ),
                const SizedBox(height: 28),
                const Text(
                  'JJAASS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3.0,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 28,
                      height: 2,
                      color: const Color(0xFF93C5FD),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'WATER MARKET',
                        style: TextStyle(
                          color: Color(0xFFBFDBFE),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 3.5,
                        ),
                      ),
                    ),
                    Container(
                      width: 28,
                      height: 2,
                      color: const Color(0xFF93C5FD),
                    ),
                  ],
                ),
                const SizedBox(height: 48),
                const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
