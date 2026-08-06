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
  final String? senderName;
  final String? senderProfilePicture;
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
    this.senderName,
    this.senderProfilePicture,
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
    String? senderName,
    String? senderProfilePicture,
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
      senderName: senderName ?? this.senderName,
      senderProfilePicture: senderProfilePicture ?? this.senderProfilePicture,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      orderId: orderId ?? this.orderId,
      subOrderId: subOrderId ?? this.subOrderId,
    );
  }


  Map<String, dynamic> toJson() => {
    'userId': userId,
    'userRole': userRole.name[0].toUpperCase() + userRole.name.substring(1),
    'type': type.name,
    'message': message,
    'senderName': senderName,
    'senderProfilePicture': senderProfilePicture,
    'isRead': isRead,
    'createdAt': Timestamp.fromDate(createdAt),
    'orderId': orderId,
    'subOrderId': subOrderId,
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
      senderName: json['senderName'],
      senderProfilePicture: json['senderProfilePicture'],
      isRead: json['isRead'] ?? false,
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      orderId: json['orderId'] ?? '',
      subOrderId: json['subOrderId'],
    );
  }
}
