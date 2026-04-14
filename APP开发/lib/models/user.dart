import 'package:hive/hive.dart';

part 'user.g.dart';

/// 用户模型
@HiveType(typeId: 7)
class User extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String? email;

  @HiveField(2)
  final String? displayName;

  @HiveField(3)
  final String? avatarUrl;

  @HiveField(4)
  final DateTime createdAt;

  @HiveField(5)
  final DateTime? lastLoginAt;

  @HiveField(6)
  final Map<String, dynamic>? preferences;

  @HiveField(7)
  final bool isPremium;

  User({
    required this.id,
    this.email,
    this.displayName,
    this.avatarUrl,
    required this.createdAt,
    this.lastLoginAt,
    this.preferences,
    this.isPremium = false,
  });

  /// 获取显示名称
  String get nameToDisplay {
    if (displayName != null && displayName!.isNotEmpty) {
      return displayName!;
    }
    if (email != null && email!.isNotEmpty) {
      return email!.split('@').first;
    }
    return '用户';
  }

  /// 是否是新用户（7天内注册）
  bool get isNewUser {
    return DateTime.now().difference(createdAt).inDays < 7;
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String?,
      displayName: json['displayName'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastLoginAt: json['lastLoginAt'] != null
          ? DateTime.parse(json['lastLoginAt'] as String)
          : null,
      preferences: json['preferences'] as Map<String, dynamic>?,
      isPremium: json['isPremium'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'createdAt': createdAt.toIso8601String(),
      'lastLoginAt': lastLoginAt?.toIso8601String(),
      'preferences': preferences,
      'isPremium': isPremium,
    };
  }

  User copyWith({
    String? id,
    String? email,
    String? displayName,
    String? avatarUrl,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    Map<String, dynamic>? preferences,
    bool? isPremium,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      preferences: preferences ?? this.preferences,
      isPremium: isPremium ?? this.isPremium,
    );
  }

  @override
  String toString() {
    return 'User(id: $id, name: $nameToDisplay)';
  }
}
