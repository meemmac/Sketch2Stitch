import 'package:cloud_firestore/cloud_firestore.dart';
import 'message.dart';
import 'user_role.dart';

class Conversation {
  final String id;
  final String customerId;
  final String otherId;
  final UserRole otherRole;
  final String orderId;
  
  // 🛡️ Denormalized fields for zero-latency inbox sync
  final String? lastMessage;
  final String? lastSenderId;
  final bool? lastMessageRead; 
  
  // 🛡️ Per-user unread tracking to prevent badges showing for senders
  final Map<String, int> unreadCounts; 
  
  final DateTime? lastReadAt;
  final bool isBlocked;
  final String? blockedBy;
  final DateTime? updatedAt;
  final bool isDeleted;
  final DateTime? deletedAt;
  final String? deletedBy;
  
  // Relationships
  List<Message>? messages;

  Conversation({
    required this.id,
    required this.customerId,
    required this.otherId,
    required this.otherRole,
    required this.orderId,
    this.lastMessage,
    this.lastSenderId,
    this.lastMessageRead,
    this.unreadCounts = const {},
    this.lastReadAt,
    this.isBlocked = false,
    this.blockedBy,
    this.updatedAt,
    this.isDeleted = false,
    this.deletedAt,
    this.deletedBy,
    this.messages = const [],
  });

  Conversation copyWith({
    String? id,
    String? customerId,
    String? otherId,
    UserRole? otherRole,
    String? orderId,
    String? lastMessage,
    String? lastSenderId,
    bool? lastMessageRead,
    Map<String, int>? unreadCounts,
    DateTime? lastReadAt,
    bool? isBlocked,
    String? blockedBy,
    DateTime? updatedAt,
    bool? isDeleted,
    DateTime? deletedAt,
    String? deletedBy,
    List<Message>? messages,
  }) {
    return Conversation(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      otherId: otherId ?? this.otherId,
      otherRole: otherRole ?? this.otherRole,
      orderId: orderId ?? this.orderId,
      lastMessage: lastMessage ?? this.lastMessage,
      lastSenderId: lastSenderId ?? this.lastSenderId,
      lastMessageRead: lastMessageRead ?? this.lastMessageRead,
      unreadCounts: unreadCounts ?? this.unreadCounts,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      isBlocked: isBlocked ?? this.isBlocked,
      blockedBy: blockedBy ?? this.blockedBy,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      deletedBy: deletedBy ?? this.deletedBy,
      messages: messages ?? this.messages,
    );
  }

  /// Use this for writing to Firestore directly.
  Map<String, dynamic> toJson() => {
    'id': id,
    'customerId': customerId,
    'otherId': otherId,
    'otherRole': otherRole.name,
    'orderId': orderId,
    'lastMessage': lastMessage,
    'lastSenderId': lastSenderId,
    'lastMessageRead': lastMessageRead,
    'unreadCounts': unreadCounts,
    'lastReadAt': lastReadAt != null ? Timestamp.fromDate(lastReadAt!) : null,
    'isBlocked': isBlocked,
    'blockedBy': blockedBy,
    'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    'isDeleted': isDeleted,
    'deletedAt': deletedAt != null ? Timestamp.fromDate(deletedAt!) : null,
    'deletedBy': deletedBy,
  };

  factory Conversation.fromJson(Map<String, dynamic> json) {
    DateTime? _parseDate(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    return Conversation(
      id: json['id'] ?? '',
      customerId: json['customerId'] ?? '',
      otherId: json['otherId'] ?? '',
      otherRole: UserRole.values.byName(json['otherRole'] ?? 'tailor'),
      orderId: json['orderId'] ?? '',
      lastMessage: json['lastMessage'],
      lastSenderId: json['lastSenderId'],
      lastMessageRead: json['lastMessageRead'] as bool?,
      unreadCounts: (json['unreadCounts'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, (value as num).toInt()),
          ) ?? {},
      lastReadAt: _parseDate(json['lastReadAt']),
      isBlocked: json['isBlocked'] ?? false,
      blockedBy: json['blockedBy'],
      updatedAt: _parseDate(json['updatedAt']),
      isDeleted: json['isDeleted'] ?? false,
      deletedAt: _parseDate(json['deletedAt']),
      deletedBy: json['deletedBy'],
    );
  }
}
