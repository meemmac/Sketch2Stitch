class Measurement {
  final String id;
  final String customerId;
  final double upperBustCircumference;
  final double roundShoulderCircumference;
  final double hipsCircumference;
  final double underBustCircumference;
  final double bustCircumference;
  final double bustSpan;
  final double shoulderToHips;
  final double shoulderToKnee;
  final double shoulderToUnderBust;
  final double shoulderToBust;
  final double thigh;
  final double knee;
  final double ankle;
  final DateTime? createdAt;

  Measurement({
    required this.id,
    required this.customerId,
    required this.upperBustCircumference,
    required this.roundShoulderCircumference,
    required this.hipsCircumference,
    required this.underBustCircumference,
    required this.bustCircumference,
    required this.bustSpan,
    required this.shoulderToHips,
    required this.shoulderToKnee,
    required this.shoulderToUnderBust,
    required this.shoulderToBust,
    required this.thigh,
    required this.knee,
    required this.ankle,
    this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'customerId': customerId,
    'upperBustCircumference': upperBustCircumference,
    'roundShoulderCircumference': roundShoulderCircumference,
    'hipsCircumference': hipsCircumference,
    'underBustCircumference': underBustCircumference,
    'bustCircumference': bustCircumference,
    'bustSpan': bustSpan,
    'shoulderToHips': shoulderToHips,
    'shoulderToKnee': shoulderToKnee,
    'shoulderToUnderBust': shoulderToUnderBust,
    'shoulderToBust': shoulderToBust,
    'thigh': thigh,
    'knee': knee,
    'ankle': ankle,
    'createdAt': createdAt?.toIso8601String(),
  };
}