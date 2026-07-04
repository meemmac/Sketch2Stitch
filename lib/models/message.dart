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
  bool isRead;

  Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderRole,
    required this.msgText,
    this.attachment,
    required this.sentAt,
    this.isRead = false,
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

  Map<String, dynamic> toJson() => {
    'id': id,
    'conversationId': conversationId,
    'senderId': senderId,
    'senderRole': senderRole.index,
    'msgText': msgText,
    'attachment': attachment,
    'sentAt': sentAt.toIso8601String(),
    'isRead': isRead,
  };
}