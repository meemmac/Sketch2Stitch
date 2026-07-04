enum ReviewTargetRole {
  retailer,
  tailor,
  product,
}

class Review {
  final String id;
  final String customerId;
  final String targetId;
  final ReviewTargetRole targetRole;
  final String? orderId;
  final double rating;
  final String comment;
  final DateTime createdAt;

  Review({
    required this.id,
    required this.customerId,
    required this.targetId,
    required this.targetRole,
    this.orderId,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'customerId': customerId,
    'targetId': targetId,
    'targetRole': targetRole.index,
    'orderId': orderId,
    'rating': rating,
    'comment': comment,
    'createdAt': createdAt.toIso8601String(),
  };
}