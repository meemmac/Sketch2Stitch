import 'package:cloud_firestore/cloud_firestore.dart';
import 'message.dart';
import 'user_role.dart';

class Conversation {
  final String id;
  final String customerId;
  final String otherId;
  final UserRole otherRole;
  final String orderId;
  // 🆕 New fields for messaging features
  final int unreadCount;
  final DateTime? lastReadAt;
  final bool isBlocked;
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
    this.unreadCount = 0,
    this.lastReadAt,
    this.isBlocked = false,
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
    int? unreadCount,
    DateTime? lastReadAt,
    bool? isBlocked,
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
      unreadCount: unreadCount ?? this.unreadCount,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      isBlocked: isBlocked ?? this.isBlocked,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      deletedBy: deletedBy ?? this.deletedBy,
      messages: messages ?? this.messages,
    );
  }

  /// Use this for writing to Firestore directly (native Timestamp type,
  /// matches the "timestamp" type declared in the schema).
  Map<String, dynamic> toJson() => {
    'id': id,
    'customerId': customerId,
    'otherId': otherId,
    'otherRole': otherRole.name,
    'orderId': orderId,
    'unreadCount': unreadCount,
    'lastReadAt': lastReadAt != null ? Timestamp.fromDate(lastReadAt!) : null,
    'isBlocked': isBlocked,
    'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    'isDeleted': isDeleted,
    'deletedAt': deletedAt != null ? Timestamp.fromDate(deletedAt!) : null,
    'deletedBy': deletedBy,
  };

  /// Handles both native Firestore Timestamp (current/new docs) and
  /// ISO8601 strings (legacy docs written before this fix), plus a safe
  /// numeric cast for unreadCount (guards against int64 vs double
  /// ambiguity coming back from Firestore).
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
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      lastReadAt: _parseDate(json['lastReadAt']),
      isBlocked: json['isBlocked'] ?? false,
      updatedAt: _parseDate(json['updatedAt']),
      isDeleted: json['isDeleted'] ?? false,
      deletedAt: _parseDate(json['deletedAt']),
      deletedBy: json['deletedBy'],
    );
  }
}