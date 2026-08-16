import 'package:cloud_firestore/cloud_firestore.dart';
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
  materialsArrived, paymentReleased, jobDeliveryDeadline,
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
  final String? tailorJobId;
  
  // These fields are for UI display only (In-Memory)
  // They are NOT saved to the Firebase "Notifications" collection
  final String? senderName;
  final String? senderProfilePicture;
  final String? cancelReason;


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
    this.tailorJobId,
    this.senderName,
    this.senderProfilePicture,
    this.cancelReason,
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
    String? tailorJobId,
    String? senderName,
    String? senderProfilePicture,
    String? cancelReason,
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
      tailorJobId: tailorJobId ?? this.tailorJobId,
      senderName: senderName ?? this.senderName,
      senderProfilePicture: senderProfilePicture ?? this.senderProfilePicture,
      cancelReason: cancelReason ?? this.cancelReason,
    );
  }

  // ⚠️ Important: toJson() only contains your original Firebase fields
  Map<String, dynamic> toJson() => {
    'userId': userId,
    'userRole': userRole.name[0].toUpperCase() + userRole.name.substring(1),
    'type': type.name,
    'message': message,
    'isRead': isRead,
    'createdAt': Timestamp.fromDate(createdAt),
    'orderId': orderId,
    'subOrderId': subOrderId,
    'tailorJobId': tailorJobId,
  };

  factory AppNotification.fromJson(Map<String, dynamic> json, [String? id]) {
    return AppNotification(
      id: id ?? json['id'] ?? '',
      userId: json['userId'] ?? '',
      userRole: UserRole.values.firstWhere(
            (e) => e.name.toLowerCase() == (json['userRole'] as String?)?.toLowerCase(),
        orElse: () => UserRole.customer,
      ),
      type: NotificationDbType.values.firstWhere(
            (t) => t.name == json['type'],
        orElse: () => NotificationDbType.newMessage,
      ),
      message: json['message'] ?? '',
      isRead: json['isRead'] ?? false,
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      orderId: json['orderId'] ?? '',
      subOrderId: json['subOrderId'],
      tailorJobId: json['tailorJobId'],
      // Note: We don't read senderName from Firebase JSON as it's fetched separately
    );
  }
}
