import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../models/user_model.dart';
import '../repositories/auth_repository.dart';

class AuthProvider extends ChangeNotifier {
  final AuthRepository _authRepository = (AppConstants.supabaseUrl != 'YOUR_SUPABASE_PROJECT_URL' &&
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

  // Set local state loading status
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // Clear previous error message
  void _clearError() {
    _errorMessage = null;
  }

  // Login handler
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      _currentUser = await _authRepository.login(
        email: email,
        password: password,
      );
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  // Signup handler
  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) async {
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
}
