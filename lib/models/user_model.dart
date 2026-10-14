import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/app_constants.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String role; // e.g., operator, technician, manager
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.createdAt,
    this.updatedAt,
  });

  /// Canonical UID alias for [id].
  String get uid => id;

  /// User display name alias for [name].
  String get displayName => name;

  /// Returns whether this user has a recognized role (operator, technician, manager).
  bool get hasRecognizedRole =>
      AppConstants.userRoles.contains(role.trim().toLowerCase());

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? role,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'createdAt': createdAt?.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }

  /// Converts this [UserModel] to a Firestore-compatible map.
  ///
  /// Writes both modern (`uid`, `displayName`) and backward-compatible (`id`, `userId`, `name`) keys.
  Map<String, dynamic> toFirestoreMap({bool isUpdate = false}) {
    final map = <String, dynamic>{
      'uid': id,
      'userId': id,
      'name': name,
      'displayName': name,
      'email': email,
      'role': role,
    };
    if (!isUpdate && createdAt != null) {
      map['createdAt'] = Timestamp.fromDate(createdAt!);
    }
    if (updatedAt != null) {
      map['updatedAt'] = Timestamp.fromDate(updatedAt!);
    }
    return map;
  }

  factory UserModel.fromMap(Map<String, dynamic> map, [String? docId]) {
    return UserModel(
      id:
          docId ??
          map['id'] as String? ??
          map['userId'] as String? ??
          map['uid'] as String? ??
          '',
      name: map['name'] as String? ?? map['displayName'] as String? ?? '',
      email: map['email'] as String? ?? '',
      role: map['role'] as String? ?? '',
      createdAt: _parseDateTime(map['createdAt']),
      updatedAt: _parseDateTime(map['updatedAt']),
    );
  }

  /// Constructs a [UserModel] from a Firestore [DocumentSnapshot].
  factory UserModel.fromFirestore(DocumentSnapshot snapshot) {
    final data =
        snapshot.data() as Map<String, dynamic>? ?? <String, dynamic>{};
    return UserModel.fromMap(data, snapshot.id);
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value);
    try {
      return (value as dynamic).toDate() as DateTime;
    } catch (_) {
      return DateTime.tryParse(value.toString());
    }
  }

  @override
  String toString() {
    return 'UserModel(id: $id, name: $name, email: $email, role: $role, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel &&
        other.id == id &&
        other.name == name &&
        other.email == email &&
        other.role == role &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(id, name, email, role, createdAt, updatedAt);
  }
}
