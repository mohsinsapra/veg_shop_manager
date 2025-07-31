class UserModel {
  final String uid;
  final String email;
  final String role;
  final String shopId;

  UserModel({
    required this.uid,
    required this.email,
    required this.role,
    required this.shopId,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      email: map['email'] ?? '',
      role: map['role'] ?? 'shop',
      shopId: map['shopId'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'role': role,
      'shopId': shopId,
    };
  }

  bool get isAdmin => role == 'admin';
}