import 'package:cloud_firestore/cloud_firestore.dart';
import 'message.dart';
import 'user_role.dart';

class Conversation {
  final String id;
  final String customerId;
  final String otherId;
  // Role of the thread initiator (`customerId`) — that party is not always a
  // customer, so the receiving side needs it to look them up.
  final UserRole customerRole;
  final UserRole otherRole;
  
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
    this.customerRole = UserRole.customer,
    required this.otherRole,
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
    UserRole? customerRole,
    UserRole? otherRole,
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
      customerRole: customerRole ?? this.customerRole,
      otherRole: otherRole ?? this.otherRole,
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
    'customerRole': customerRole.name,
    'otherRole': otherRole.name,
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
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    UserRole parseRole(dynamic r, {UserRole fallback = UserRole.tailor}) {
      if (r == null) return fallback;
      final name = r.toString().toLowerCase().trim();
      return UserRole.values.firstWhere(
        (e) => e.name.toLowerCase() == name,
        orElse: () => fallback,
      );
    }

    final String cId = (json['customerId'] ?? '').toString().trim();
    final String oId = (json['otherId'] ?? '').toString().trim();
    final String lastSender = (json['lastSenderId'] ?? '').toString().trim();

    Map<String, int> parsedUnread = {};
    if (json['unreadCounts'] is Map) {
      (json['unreadCounts'] as Map).forEach((k, v) {
        if (v is num) parsedUnread[k.toString().trim()] = v.toInt();
      });
    }
    
    // Support legacy singular unreadCount if unreadCounts was not populated
    if (parsedUnread.isEmpty && json['unreadCount'] is num && (json['unreadCount'] as num) > 0) {
      final target = (lastSender == cId) ? oId : cId;
      if (target.isNotEmpty) {
        parsedUnread[target] = (json['unreadCount'] as num).toInt();
      }
    }

    return Conversation(
      id: json['id'] ?? '',
      customerId: cId,
      otherId: oId,
      customerRole: parseRole(json['customerRole'], fallback: UserRole.customer),
      otherRole: parseRole(json['otherRole']),
      lastMessage: json['lastMessage'],
      lastSenderId: lastSender.isNotEmpty ? lastSender : null,
      lastMessageRead: json['lastMessageRead'] as bool?,
      unreadCounts: parsedUnread,
      lastReadAt: parseDate(json['lastReadAt']),
      isBlocked: json['isBlocked'] ?? false,
      blockedBy: json['blockedBy'],
      updatedAt: parseDate(json['updatedAt']),
      isDeleted: json['isDeleted'] ?? false,
      deletedAt: parseDate(json['deletedAt']),
      deletedBy: json['deletedBy'],
    );
  }
}
