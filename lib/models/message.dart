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

  Map<String, dynamic> toJson() => {
    'id': id,
    'conversationId': conversationId,
    'senderId': senderId,
    'senderRole': senderRole.name,
    'msgText': msgText,
    'attachment': attachment,
    'sentAt': sentAt.toIso8601String(),
    'replyToMessageId': replyToMessageId,
    'replyToText': replyToText,
    'replyToSender': replyToSender,
    'isRead': isRead,
    'readAt': readAt?.toIso8601String(),
  };

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] ?? '',
      conversationId: json['conversationId'] ?? '',
      senderId: json['senderId'] ?? '',
      senderRole: UserRole.values.byName(json['senderRole'] ?? 'customer'),
      msgText: json['msgText'] ?? '',
      attachment: json['attachment'],
      sentAt: json['sentAt'] != null
          ? DateTime.parse(json['sentAt'])
          : DateTime.now(),
      replyToMessageId: json['replyToMessageId'],
      replyToText: json['replyToText'],
      replyToSender: json['replyToSender'],
      isRead: json['isRead'] ?? false,
      readAt: json['readAt'] != null
          ? DateTime.parse(json['readAt'])
          : null,
    );
  }
}