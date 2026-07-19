import 'message.dart';
import 'user_role.dart';

class Conversation {
  final String id;
  final String customerId;
  final String otherId;
  final UserRole otherRole;
  final String orderId;

  // Relationships
  List<Message>? messages;

  Conversation({
    required this.id,
    required this.customerId,
    required this.otherId,
    required this.otherRole,
    required this.orderId,
    this.messages = const [],
  });

  Conversation copyWith({
    String? id,
    String? customerId,
    String? otherId,
    UserRole? otherRole,
    String? orderId,
    List<Message>? messages,
  }) {
    return Conversation(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      otherId: otherId ?? this.otherId,
      otherRole: otherRole ?? this.otherRole,
      orderId: orderId ?? this.orderId,
      messages: messages ?? this.messages,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'customerId': customerId,
    'otherId': otherId,
    'otherRole': otherRole.name,
    'orderId': orderId,
  };

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] ?? '',
      customerId: json['customerId'] ?? '',
      otherId: json['otherId'] ?? '',
      otherRole: UserRole.values.byName(json['otherRole'] ?? 'tailor'),
      orderId: json['orderId'] ?? '',
    );
  }
}