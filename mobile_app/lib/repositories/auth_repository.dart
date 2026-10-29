import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';

abstract class AuthRepository {
  Future<UserModel> login({required String email, required String password});
  Future<UserModel> signUp({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  });
  Future<void> logout();
  Future<UserModel?> getCurrentUser();
  Future<UserModel> updateProfile({
    required UserModel currentUser,
    required String name,
    required String phone,
  });
}

class MockAuthRepository implements AuthRepository {
  // Account store: normalized email -> Map of credentials and user model
  static final Map<String, Map<String, dynamic>> _userStore = {};

  @override
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));

    if (email.isEmpty || password.isEmpty) {
      throw Exception('Email and password cannot be empty.');
    }

    final normalizedEmail = email.trim().toLowerCase();
    final account = _userStore[normalizedEmail];

    if (account == null) {
      throw Exception(
        'No account found with this email. Please sign up first.',
      );
    }

    if (account['password'] != password) {
      throw Exception('Incorrect password. Please try again.');
    }

    return account['user'] as UserModel;
  }

  @override
  Future<UserModel> signUp({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      throw Exception('All fields are required.');
    }

    if (password.length < 6) {
      throw Exception('Password must be at least 6 characters.');
    }

    final normalizedEmail = email.trim().toLowerCase();
    if (_userStore.containsKey(normalizedEmail)) {
      throw Exception(
        'An account with this email already exists. Please log in.',
      );
    }

    final user = UserModel(
      id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      email: email.trim(),
      role: role,
    );

    _userStore[normalizedEmail] = {'user': user, 'password': password};

    ApiService.addMockUser(user);

    return user;
  }

  @override
  Future<void> logout() async {
    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    return null;
  }

  @override
  Future<UserModel> updateProfile({
    required UserModel currentUser,
    required String name,
    required String phone,
  }) async {
    final updated = UserModel(
      id: currentUser.id,
      name: name,
      email: currentUser.email,
      role: currentUser.role,
    );
    final normalizedEmail = currentUser.email.trim().toLowerCase();
    if (_userStore.containsKey(normalizedEmail)) {
      _userStore[normalizedEmail]!['user'] = updated;
      _userStore[normalizedEmail]!['phone'] = phone;
    }
    return updated;
  }
}

class SupabaseAuthRepository implements AuthRepository {
  SupabaseClient get _client => Supabase.instance.client;

  @override
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    final user = response.user;
    if (user == null) {
      throw Exception('Login failed: User record is empty.');
    }

    final metaName = user.userMetadata?['name'] as String?;

    try {
      // Query profiles table for user details
      final profile = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();
      final model = UserModel.fromJson(profile);
      return UserModel(
        id: model.id,
        name: (metaName != null && metaName.isNotEmpty) ? metaName : model.name,
        email: model.email,
        role: model.role,
      );
    } catch (e) {
      // Fallback if profiles table is not yet migrated
      return UserModel(
        id: user.id,
        name: (metaName != null && metaName.isNotEmpty)
            ? metaName
            : email.split('@').first,
        email: email,
        role: UserRole.customer,
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

      final metaName = user.userMetadata?['name'] as String?;

      try {
        final profile = await _client
            .from('profiles')
            .select()
            .eq('id', user.id)
            .single();
        final model = UserModel.fromJson(profile);
        return UserModel(
          id: model.id,
          name: (metaName != null && metaName.isNotEmpty)
              ? metaName
              : model.name,
          email: model.email,
          role: model.role,
        );
      } catch (e) {
        final email = user.email ?? '';
        return UserModel(
          id: user.id,
          name: (metaName != null && metaName.isNotEmpty)
              ? metaName
              : email.split('@').first,
          email: email,
          role: UserRole.customer,
        );
      }
    } catch (e) {
      return null;
    }
  }

  @override
  Future<UserModel> updateProfile({
    required UserModel currentUser,
    required String name,
    required String phone,
  }) async {
    final updated = UserModel(
      id: currentUser.id,
      name: name,
      email: currentUser.email,
      role: currentUser.role,
    );
    try {
      await _client.auth.updateUser(
        UserAttributes(data: {'name': name, 'phone': phone}),
      );
    } catch (e) {
      debugPrint('Supabase auth metadata update skipped: $e');
    }
    try {
      await _client
          .from('profiles')
          .update({'name': name})
          .eq('id', currentUser.id);
    } catch (e) {
      debugPrint('Supabase profiles table update skipped: $e');
    }
    return updated;
  }
}
