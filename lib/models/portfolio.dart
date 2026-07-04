class Portfolio {
  final String id;
  final String tailorId;
  final String? image;
  final String? description;

  Portfolio({
    required this.id,
    required this.tailorId,
    this.image,
    this.description,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'tailorId': tailorId,
    'image': image,
    'description': description,
  };
}