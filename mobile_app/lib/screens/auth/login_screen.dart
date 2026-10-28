import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/water_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      Helpers.showSnackBar(context, 'Login successful! Welcome back.');
      final user = authProvider.currentUser;
      if (user != null) {
        _routeToDashboard(user.role);
      }
    } else {
      Helpers.showSnackBar(
        context,
        authProvider.errorMessage ?? 'Authentication failed.',
        isError: true,
      );
    }
  }

  void _routeToDashboard(UserRole role) {
    switch (role) {
      case UserRole.customer:
        Navigator.of(context).pushReplacementNamed(AppRoutes.customerDashboard);
        break;
      case UserRole.driver:
        Navigator.of(context).pushReplacementNamed(AppRoutes.driverDashboard);
        break;
      case UserRole.admin:
        Helpers.showSnackBar(context, 'Admin accounts must log in via the Admin Panel.', isError: true);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 700;
    final isDark = theme.brightness == Brightness.dark;

    Widget formContent() {
      return Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // App logo / header icon
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.12),
                    width: 1,
                  ),
                ),
                child: const WaterDropletLogo(size: 60),
              ),
            ),
            const SizedBox(height: 20),
            // Welcoming Header
            Center(
              child: Text(
                AppConstants.appName,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppTheme.primaryColor,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                'WATER REFILLING STATION',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3.0,
                  color: Colors.grey.shade500,
                ),
              ),
            ),
            const SizedBox(height: 28),
            CustomTextField(
              controller: _emailController,
              labelText: 'Email Address',
              hintText: 'Enter your email address',
              prefixIcon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your email';
                }
                if (!Helpers.isValidEmail(value)) {
                  return 'Please enter a valid email address';
                }
                return null;
              },
            ),
            const SizedBox(height: 18),
            CustomTextField(
              controller: _passwordController,
              labelText: 'Password',
              hintText: 'Enter your password',
              prefixIcon: Icons.lock_outlined,
              isPassword: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your password';
                }
                if (value.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  Helpers.showSnackBar(
                    context,
                    'Password reset link simulated!',
                  );
                },
                child: const Text(
                  'Forgot Password?',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Consumer<AuthProvider>(
              builder: (context, auth, _) {
                return CustomButton(
                  text: 'Sign In',
                  isLoading: auth.isLoading,
                  onPressed: _handleLogin,
                  gradientColors: const [
                    AppTheme.primaryColor,
                    AppTheme.secondaryColor,
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            // Go to registration page
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  "Don't have an account? ",
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).pushNamed(AppRoutes.register);
                  },
                  child: const Text(
                    'Sign Up',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: WaveBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: isDesktop
                ? Container(
                    width: 450,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 48,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark
                            ? Colors.white10
                            : const Color(0xFFE2E8F0),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: formContent(),
                  )
                : Container(
                    constraints: const BoxConstraints(maxWidth: 450),
                    child: formContent(),
                  ),
          ),
        ),
      ),
    );
  }
}
