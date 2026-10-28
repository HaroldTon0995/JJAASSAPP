enum UserRole {
  customer,
  driver,
  admin,
}

class UserModel {
  final String id;
  final String name;
  final String email;
  final UserRole role;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role.name,
    };
  }

  // Create from JSON
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      role: UserRole.values.byName(json['role'] as String),
    );
  }

  // Helper helper to get role displayName
  String get roleDisplayName {
    switch (role) {
      case UserRole.customer:
        return 'Customer';
      case UserRole.driver:
        return 'Driver';
      case UserRole.admin:
        return 'Administrator';
    }
  }
}
