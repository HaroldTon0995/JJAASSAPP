import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';

abstract class AuthRepository {
  Future<UserModel> login({required String email, required String password});
  Future<UserModel> signUp({required String name, required String email, required String password, required UserRole role});
  Future<void> logout();
  Future<UserModel?> getCurrentUser();
}

class MockAuthRepository implements AuthRepository {
  @override
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    // Simulate API network call delay
    await Future.delayed(const Duration(milliseconds: 1000));

    // Mock validation
    if (email.isEmpty || password.isEmpty) {
      throw Exception('Email and password cannot be empty.');
    }

    if (password.length < 6) {
      throw Exception('Password must be at least 6 characters.');
    }

    // Auto-detect role from email pattern
    UserRole detectedRole = UserRole.customer;
    if (email.toLowerCase().contains('admin')) {
      detectedRole = UserRole.admin;
    } else if (email.toLowerCase().contains('driver')) {
      detectedRole = UserRole.driver;
    }

    // Mock successful login returning corresponding user
    final user = UserModel(
      id: 'usr_${email.hashCode.abs()}',
      name: email.split('@').first.toUpperCase(),
      email: email,
      role: detectedRole,
    );

    // Sync user with mock list
    ApiService.addMockUser(user);

    return user;
  }

  @override
  Future<UserModel> signUp({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    await Future.delayed(const Duration(milliseconds: 1200));

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      throw Exception('All fields are required.');
    }

    if (password.length < 6) {
      throw Exception('Password must be at least 6 characters.');
    }

    final user = UserModel(
      id: 'usr_${email.hashCode.abs()}',
      name: name,
      email: email,
      role: role,
    );

    // Add registered user directly to ApiService's mock user directory
    ApiService.addMockUser(user);

    return user;
  }

  @override
  Future<void> logout() async {
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    // Return null in mock mode to let users login manually
    return null;
  }
}

class SupabaseAuthRepository implements AuthRepository {
  SupabaseClient get _client => Supabase.instance.client;

  @override
  Future<UserModel> login({required String email, required String password}) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    final user = response.user;
    if (user == null) {
      throw Exception('Login failed: User record is empty.');
    }

    try {
      // Query profiles table for user details
      final profile = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();
      return UserModel.fromJson(profile);
    } catch (e) {
      // Graceful fallback if database table profiles has not been created yet
      UserRole role = UserRole.customer;
      if (email.toLowerCase().contains('admin')) {
        role = UserRole.admin;
      } else if (email.toLowerCase().contains('driver')) {
        role = UserRole.driver;
      }
      return UserModel(
        id: user.id,
        name: email.split('@').first.toUpperCase(),
        email: email,
        role: role,
      );
    }
  }

  @override
  Future<UserModel> signUp({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
    );

    final user = response.user;
    if (user == null) {
      throw Exception('Registration failed: User is empty.');
    }

    final newUser = UserModel(
      id: user.id,
      name: name,
      email: email,
      role: role,
    );

    try {
      // Insert user profile into profiles table
      await _client.from('profiles').insert(newUser.toJson());
    } catch (e) {
      debugPrint('Profiles table insert skipped: $e');
    }

    return newUser;
  }

  @override
  Future<void> logout() async {
    await _client.auth.signOut();
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    try {
      final session = _client.auth.currentSession;
      if (session == null) return null;
      final user = _client.auth.currentUser;
      if (user == null) return null;

      try {
        final profile = await _client
            .from('profiles')
            .select()
            .eq('id', user.id)
            .single();
        return UserModel.fromJson(profile);
      } catch (e) {
        // Fallback
        UserRole role = UserRole.customer;
        final email = user.email ?? '';
        if (email.toLowerCase().contains('admin')) {
          role = UserRole.admin;
        } else if (email.toLowerCase().contains('driver')) {
          role = UserRole.driver;
        }
        return UserModel(
          id: user.id,
          name: email.split('@').first.toUpperCase(),
          email: email,
          role: role,
        );
      }
    } catch (e) {
      return null;
    }
  }
}
