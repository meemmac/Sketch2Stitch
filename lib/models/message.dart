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

  Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderRole,
    required this.msgText,
    this.attachment,
    required this.sentAt,
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
  }) {
    return Message(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      senderRole: senderRole ?? this.senderRole,
      msgText: msgText ?? this.msgText,
      attachment: attachment ?? this.attachment,
      sentAt: sentAt ?? this.sentAt,
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
    );
  }
}
