enum MemberRole { admin, member }

class MemberEntity {
  final String id; // lowercased email
  final String email;
  final String displayName;
  final MemberRole role;
  final List<String> shopIds;
  final bool active;
  final String? uid;

  const MemberEntity({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
    required this.shopIds,
    required this.active,
    required this.uid,
  });

  bool get isAdmin => role == MemberRole.admin;

  Map<String, dynamic> toMap() => {
        'email': email.toLowerCase(),
        'displayName': displayName,
        'role': role.name,
        'shopIds': shopIds,
        'active': active,
        'uid': uid,
      };

  factory MemberEntity.fromMap(String id, Map<String, dynamic> map) => MemberEntity(
        id: id,
        email: (map['email'] as String? ?? id).toLowerCase(),
        displayName: map['displayName'] as String? ?? '',
        role: (map['role'] as String?) == 'admin' ? MemberRole.admin : MemberRole.member,
        shopIds: (map['shopIds'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        active: map['active'] as bool? ?? true,
        uid: map['uid'] as String?,
      );

  MemberEntity copyWith({
    String? email,
    String? displayName,
    MemberRole? role,
    List<String>? shopIds,
    bool? active,
    String? uid,
  }) =>
      MemberEntity(
        id: id,
        email: email ?? this.email,
        displayName: displayName ?? this.displayName,
        role: role ?? this.role,
        shopIds: shopIds ?? this.shopIds,
        active: active ?? this.active,
        uid: uid ?? this.uid,
      );

  @override
  bool operator ==(Object other) =>
      other is MemberEntity &&
      other.id == id &&
      other.email == email &&
      other.displayName == displayName &&
      other.role == role &&
      _listEq(other.shopIds, shopIds) &&
      other.active == active &&
      other.uid == uid;

  @override
  int get hashCode =>
      Object.hash(id, email, displayName, role, Object.hashAll(shopIds), active, uid);
}

bool _listEq(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
