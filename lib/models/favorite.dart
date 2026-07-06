enum FavoriteTargetRole {
  retailer,
  tailor,
}

class Favorite {
  final String id;
  final String customerId;
  final String targetId;
  final FavoriteTargetRole targetRole;

  Favorite({
    required this.id,
    required this.customerId,
    required this.targetId,
    required this.targetRole,
  });

  Favorite copyWith({
    String? id,
    String? customerId,
    String? targetId,
    FavoriteTargetRole? targetRole,
  }) {
    return Favorite(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      targetId: targetId ?? this.targetId,
      targetRole: targetRole ?? this.targetRole,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'customerId': customerId,
    'targetId': targetId,
    'targetRole': targetRole.index,
  };

  factory Favorite.fromJson(Map<String, dynamic> json) {
    return Favorite(
      id: json['id'] ?? '',
      customerId: json['customerId'] ?? '',
      targetId: json['targetId'] ?? '',
      targetRole: FavoriteTargetRole.values[json['targetRole'] ?? 0],
    );
  }
}