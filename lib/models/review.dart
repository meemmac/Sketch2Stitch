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

  Review({
    required this.id,
    required this.customerId,
    required this.targetId,
    required this.targetRole,
    this.orderId,
    required this.rating,
    required this.comment,
  });

  Review copyWith({
    String? id,
    String? customerId,
    String? targetId,
    ReviewTargetRole? targetRole,
    String? orderId,
    double? rating,
    String? comment,
  }) {
    return Review(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      targetId: targetId ?? this.targetId,
      targetRole: targetRole ?? this.targetRole,
      orderId: orderId ?? this.orderId,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'customerId': customerId,
    'targetId': targetId,
    'targetRole': targetRole.index,
    'orderId': orderId,
    'rating': rating,
    'comment': comment,
  };

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'] ?? '',
      customerId: json['customerId'] ?? '',
      targetId: json['targetId'] ?? '',
      targetRole: ReviewTargetRole.values[json['targetRole'] ?? 0],
      orderId: json['orderId'],
      rating: (json['rating'] ?? 0).toDouble(),
      comment: json['comment'] ?? '',
    );
  }
}