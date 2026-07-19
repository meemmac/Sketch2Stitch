import 'user_role.dart';

enum NotificationDbType {
  // customer
  orderConfirmed, suborderPreparing, suborderPacked, suborderDelivered,
  itemWindowClosing, tailorSearchPrompt, jobRejected, quoteReceived,
  quoteExpired, garmentCompleted, itemShipped, orderCompleted,
  // retailer
  suborderPlaced, paymentConfirmed, deliveryReminder,
  // tailor
  jobRequested, selectionDeadlineReminder, jobConfirmed,
  materialsArrived, paymentReleased,
  // shared
  newMessage, reviewReceived,
}

class AppNotification {
  final String id;
  final String userId;
  final UserRole userRole;
  final NotificationDbType type;
  final String message;
  final bool isRead;
  final DateTime createdAt;
  final String orderId;
  final String? subOrderId;

  AppNotification({
    required this.id,
    required this.userId,
    required this.userRole,
    required this.type,
    required this.message,
    this.isRead = false,
    required this.createdAt,
    required this.orderId,
    this.subOrderId,
  });

  AppNotification copyWith({
    String? id,
    String? userId,
    UserRole? userRole,
    NotificationDbType? type,
    String? message,
    bool? isRead,
    DateTime? createdAt,
    String? orderId,
    String? subOrderId,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userRole: userRole ?? this.userRole,
      type: type ?? this.type,
      message: message ?? this.message,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      orderId: orderId ?? this.orderId,
      subOrderId: subOrderId ?? this.subOrderId,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'userRole': userRole.name,
    'type': type.name,
    'message': message,
    'isRead': isRead,
    'createdAt': createdAt.toIso8601String(),
    'orderId': orderId,
    'subOrderId': subOrderId,
  };

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      userRole: UserRole.values.byName(json['userRole'] ?? 'customer'),
      type: NotificationDbType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => NotificationDbType.newMessage,
      ),
      message: json['message'] ?? '',
      isRead: json['isRead'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      orderId: json['orderId'] ?? '',
      subOrderId: json['subOrderId'],
    );
  }
}