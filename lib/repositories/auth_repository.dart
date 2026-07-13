import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';

abstract class AuthRepository {
  Future<UserModel> login({required String email, required String password});
  Future<UserModel> signUp({required String name, required String email, required String password, required UserRole role});
  Future<void> logout();
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
    return UserModel(
      id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
      name: email.split('@').first.toUpperCase(),
      email: email,
      role: detectedRole,
    );
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

    return UserModel(
      id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      email: email,
      role: role,
    );
  }

  @override
  Future<void> logout() async {
    await Future.delayed(const Duration(milliseconds: 500));
  }
}

class SupabaseAuthRepository implements AuthRepository {
  final SupabaseClient _client = Supabase.instance.client;

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
}
