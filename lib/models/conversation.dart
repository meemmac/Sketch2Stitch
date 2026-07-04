class Conversation {
  final String id;
  final String customerId;
  final String otherId;
  final String otherRole; // 'tailor' or 'retailer'
  final String? orderId;
  final String? lastMessage;
  final DateTime? lastMessageAt;

  Conversation({
    required this.id,
    required this.customerId,
    required this.otherId,
    required this.otherRole,
    this.orderId,
    this.lastMessage,
    this.lastMessageAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'customerId': customerId,
    'otherId': otherId,
    'otherRole': otherRole,
    'orderId': orderId,
    'lastMessage': lastMessage,
    'lastMessageAt': lastMessageAt?.toIso8601String(),
  };
}