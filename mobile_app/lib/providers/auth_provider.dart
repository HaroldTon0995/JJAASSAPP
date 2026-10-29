import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/app_constants.dart';
import '../models/user_model.dart';
import '../repositories/auth_repository.dart';

class AuthProvider extends ChangeNotifier {
  final AuthRepository _authRepository =
      (AppConstants.supabaseUrl != 'YOUR_SUPABASE_PROJECT_URL' &&
          AppConstants.supabaseAnonKey != 'YOUR_SUPABASE_PROJECT_ANON_KEY')
      ? SupabaseAuthRepository()
      : MockAuthRepository();

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;

  String get currentPhone {
    try {
      final metaPhone =
          Supabase.instance.client.auth.currentUser?.userMetadata?['phone']
              as String?;
      if (metaPhone != null && metaPhone.trim().isNotEmpty) {
        return metaPhone.trim();
      }
    } catch (_) {}
    return '+63 912 345 6789';
  }

  Future<void> updateProfile({
    required String name,
    required String phone,
  }) async {
    final trimmedName = name.trim();
    final trimmedPhone = phone.trim();

    final baseUser =
        _currentUser ??
        UserModel(
          id: 'customer_default',
          name: trimmedName.isNotEmpty ? trimmedName : 'Customer User',
          email: 'customer@jjaass.com',
          role: UserRole.customer,
        );

    final updatedName = trimmedName.isNotEmpty ? trimmedName : baseUser.name;
    final updatedPhone = trimmedPhone.isNotEmpty ? trimmedPhone : currentPhone;

    _currentUser = await _authRepository.updateProfile(
      currentUser: baseUser,
      name: updatedName,
      phone: updatedPhone,
    );
    notifyListeners();
  }

  // Set local state loading status
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // Clear previous error message
  void _clearError() {
    _errorMessage = null;
  }

  // Login handler (Only Customer and Driver accounts can log in to the mobile app)
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final loggedIn = await _authRepository.login(
        email: email,
        password: password,
      );
      if (loggedIn.role == UserRole.admin) {
        await _authRepository.logout();
        _currentUser = null;
        _errorMessage =
            'Admin accounts cannot log in to the mobile application. Only Customer and Driver accounts can log in here.';
        _setLoading(false);
        return false;
      }
      _currentUser = loggedIn;
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  // Signup handler (Mobile App sign-up is strictly for Customer accounts;
  // Driver and Admin roles are assigned by an Administrator in the Admin Panel)
  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
    UserRole role = UserRole.customer,
  }) async {
    if (role != UserRole.customer) {
      _errorMessage =
          'Only Customer accounts can be registered in the mobile app. Driver accounts must be authorized by the Admin.';
      notifyListeners();
      return false;
    }
    _setLoading(true);
    _clearError();

    try {
      _currentUser = await _authRepository.signUp(
        name: name,
        email: email,
        password: password,
        role: role,
      );
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  // Logout handler
  Future<void> logout() async {
    _setLoading(true);
    try {
      await _authRepository.logout();
      _currentUser = null;
      _clearError();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // Restore user session on startup
  Future<bool> checkSession() async {
    _setLoading(true);
    _clearError();
    try {
      final user = await _authRepository.getCurrentUser();
      if (user != null && user.role == UserRole.admin) {
        await _authRepository.logout();
        _currentUser = null;
        _errorMessage =
            'Admin accounts cannot log in to the mobile application. Only Customer and Driver accounts can log in here.';
        _setLoading(false);
        return false;
      }
      _currentUser = user;
      _setLoading(false);
      return _currentUser != null;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }
}
