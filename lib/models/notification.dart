class Notification {
  final String id;
  final String userId;
  final String userRole;
  final String message;
  final bool isRead;
  final DateTime createdAt;

  Notification({
    required this.id,
    required this.userId,
    required this.userRole,
    required this.message,
    this.isRead = false,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'userRole': userRole,
    'message': message,
    'isRead': isRead,
    'createdAt': createdAt.toIso8601String(),
  };
}