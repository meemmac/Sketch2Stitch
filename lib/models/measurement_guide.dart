class MeasurementGuide {
  final String id;
  final String text;
  final String imageUrl;

  MeasurementGuide({
    required this.id,
    required this.text,
    required this.imageUrl,
  });

  MeasurementGuide copyWith({
    String? id,
    String? text,
    String? imageUrl,
  }) {
    return MeasurementGuide(
      id: id ?? this.id,
      text: text ?? this.text,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'imageUrl': imageUrl,
  };

  factory MeasurementGuide.fromJson(Map<String, dynamic> json) {
    return MeasurementGuide(
      id: json['id'] ?? '',
      text: json['text'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
    );
  }
}