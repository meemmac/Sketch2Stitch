import 'user_role.dart';

class AppNotification {
  final String id;
  final String userId;
  final UserRole userRole;
  final String message;
  final bool isRead;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.userId,
    required this.userRole,
    required this.message,
    this.isRead = false,
    required this.createdAt,
  });

  AppNotification copyWith({
    String? id,
    String? userId,
    UserRole? userRole,
    String? message,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userRole: userRole ?? this.userRole,
      message: message ?? this.message,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'userRole': userRole.name,
    'message': message,
    'isRead': isRead,
    'createdAt': createdAt.toIso8601String(),
  };

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      userRole: UserRole.values.byName(json['userRole'] ?? 'customer'),
      message: json['message'] ?? '',
      isRead: json['isRead'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }
}