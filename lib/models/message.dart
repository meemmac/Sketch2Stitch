enum SenderRole {
  customer,
  tailor,
  retailer,
}

class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final SenderRole senderRole;
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
      case SenderRole.customer:
        return 'Customer';
      case SenderRole.tailor:
        return 'Tailor';
      case SenderRole.retailer:
        return 'Retailer';
    }
  }

  Message copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    SenderRole? senderRole,
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
    'senderRole': senderRole.index,
    'msgText': msgText,
    'attachment': attachment,
    'sentAt': sentAt.toIso8601String(),
  };

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] ?? '',
      conversationId: json['conversationId'] ?? '',
      senderId: json['senderId'] ?? '',
      senderRole: SenderRole.values[json['senderRole'] ?? 0],
      msgText: json['msgText'] ?? '',
      attachment: json['attachment'],
      sentAt: json['sentAt'] != null 
          ? DateTime.parse(json['sentAt']) 
          : DateTime.now(),
    );
  }
}
