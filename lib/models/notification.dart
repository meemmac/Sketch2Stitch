class Notifications {
  final String id;
  final String userId;
  final String userRole;
  final String message;
  final bool isRead;
  final DateTime createdAt;

  Notifications({
    required this.id,
    required this.userId,
    required this.userRole,
    required this.message,
    this.isRead = false,
    required this.createdAt,  
  });

  Notifications copyWith({
    String? id,
    String? userId,
    String? userRole,
    String? message,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return Notifications(
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
    'userRole': userRole,
    'message': message,
    'isRead': isRead,
    'createdAt': createdAt.toIso8601String(),  // Convert to string
  };

  factory Notifications.fromJson(Map<String, dynamic> json) {
    return Notifications(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      userRole: json['userRole'] ?? '',
      message: json['message'] ?? '',
      isRead: json['isRead'] ?? false,
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),  // Fallback to now if null
    );
  }
}