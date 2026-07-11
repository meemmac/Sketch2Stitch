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

  Portfolio copyWith({
    String? id,
    String? tailorId,
    String? image,
    String? description,
  }) {
    return Portfolio(
      id: id ?? this.id,
      tailorId: tailorId ?? this.tailorId,
      image: image ?? this.image,
      description: description ?? this.description,
    );
  }


  Map<String, dynamic> toJson() => {
    'id': id,
    'tailorId': tailorId,
    'image': image,
    'description': description,
  };

  factory Portfolio.fromJson(Map<String, dynamic> json) {
    return Portfolio(
      id: json['id'] ?? '',
      tailorId: json['tailorId'] ?? '',
      image: json['image'],
      description: json['description'],
    );
  }
}