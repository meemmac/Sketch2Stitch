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

  Map<String, dynamic> toJson() => {
    'id': id,
    'customerId': customerId,
    'targetId': targetId,
    'targetRole': targetRole.index,
  };
}