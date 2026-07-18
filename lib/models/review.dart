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
  final DateTime createdAt; // ✅ Added createdAt

  Review({
    required this.id,
    required this.customerId,
    required this.targetId,
    required this.targetRole,
    this.orderId,
    required this.rating,
    required this.comment,
    required this.createdAt, // ✅ Added to constructor
  });

  Review copyWith({
    String? id,
    String? customerId,
    String? targetId,
    ReviewTargetRole? targetRole,
    String? orderId,
    double? rating,
    String? comment,
    DateTime? createdAt, // ✅ Added to copyWith
  }) {
    return Review(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      targetId: targetId ?? this.targetId,
      targetRole: targetRole ?? this.targetRole,
      orderId: orderId ?? this.orderId,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt, // ✅ Added to copyWith
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
    'createdAt': createdAt.toIso8601String(), // ✅ Added to toJson
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
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()), // ✅ Added to fromJson
    );
  }

  // Helper method to get time ago string
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 365) {
      return '${difference.inDays ~/ 365} year${(difference.inDays ~/ 365) > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 30) {
      return '${difference.inDays ~/ 30} month${(difference.inDays ~/ 30) > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 7) {
      return '${difference.inDays ~/ 7} week${(difference.inDays ~/ 7) > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 1) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays == 1) {
      return '1 day ago';
    } else if (difference.inHours > 1) {
      return '${difference.inHours} hours ago';
    } else if (difference.inHours == 1) {
      return '1 hour ago';
    } else if (difference.inMinutes > 1) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inMinutes == 1) {
      return '1 minute ago';
    } else {
      return 'Just now';
    }
  }

  // Helper to format date as string
  String get formattedDate {
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }

  // Helper to get full date and time
  String get fullDateTime {
    return '${createdAt.day}/${createdAt.month}/${createdAt.year} at ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
  }
}