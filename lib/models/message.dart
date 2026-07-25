import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_role.dart';

// SenderRole is an alias for UserRole — same values: customer, tailor, retailer
typedef SenderRole = UserRole;

class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final UserRole senderRole;
  final String msgText;
  final String? attachment;
  final DateTime sentAt;
  // 🆕 New fields for reply and read features
  final String? replyToMessageId;
  final String? replyToText;
  final String? replyToSender;
  final bool isRead;
  final DateTime? readAt;

  Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderRole,
    required this.msgText,
    this.attachment,
    required this.sentAt,
    this.replyToMessageId,
    this.replyToText,
    this.replyToSender,
    this.isRead = false,
    this.readAt,
  });

  String get senderRoleText {
    switch (senderRole) {
      case UserRole.customer:
        return 'Customer';
      case UserRole.tailor:
        return 'Tailor';
      case UserRole.retailer:
        return 'Retailer';
    }
  }

  Message copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    UserRole? senderRole,
    String? msgText,
    String? attachment,
    DateTime? sentAt,
    String? replyToMessageId,
    String? replyToText,
    String? replyToSender,
    bool? isRead,
    DateTime? readAt,
  }) {
    return Message(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      senderRole: senderRole ?? this.senderRole,
      msgText: msgText ?? this.msgText,
      attachment: attachment ?? this.attachment,
      sentAt: sentAt ?? this.sentAt,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      replyToText: replyToText ?? this.replyToText,
      replyToSender: replyToSender ?? this.replyToSender,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
    );
  }

  /// Use this for writing to Firestore directly (native Timestamp type,
  /// matches the "timestamp" type declared in the schema).
  Map<String, dynamic> toJson() => {
    'id': id,
    'conversationId': conversationId,
    'senderId': senderId,
    'senderRole': senderRole.name,
    'msgText': msgText,
    'attachment': attachment,
    'sentAt': Timestamp.fromDate(sentAt),
    'replyToMessageId': replyToMessageId,
    'replyToText': replyToText,
    'replyToSender': replyToSender,
    'isRead': isRead,
    'readAt': readAt != null ? Timestamp.fromDate(readAt!) : null,
  };

  /// Handles both native Firestore Timestamp (current/new docs) and
  /// ISO8601 strings (legacy docs written before this fix).
  factory Message.fromJson(Map<String, dynamic> json) {
    DateTime? _parseDate(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    return Message(
      id: json['id'] ?? '',
      conversationId: json['conversationId'] ?? '',
      senderId: json['senderId'] ?? '',
      senderRole: UserRole.values.byName(json['senderRole'] ?? 'customer'),
      msgText: json['msgText'] ?? '',
      attachment: json['attachment'],
      sentAt: _parseDate(json['sentAt']) ?? DateTime.now(),
      replyToMessageId: json['replyToMessageId'],
      replyToText: json['replyToText'],
      replyToSender: json['replyToSender'],
      isRead: json['isRead'] ?? false,
      readAt: _parseDate(json['readAt']),
    );
  }
}