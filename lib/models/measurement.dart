
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
  });

  Measurement copyWith({
    String? id,
    String? customerId,
    double? upperBustCircumference,
    double? roundShoulderCircumference,
    double? hipsCircumference,
    double? underBustCircumference,
    double? bustCircumference,
    double? bustSpan,
    double? shoulderToHips,
    double? shoulderToKnee,
    double? shoulderToUnderBust,
    double? shoulderToBust,
    double? thigh,
    double? knee,
    double? ankle,
  }) {
    return Measurement(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      upperBustCircumference: upperBustCircumference ?? this.upperBustCircumference,
      roundShoulderCircumference: roundShoulderCircumference ?? this.roundShoulderCircumference,
      hipsCircumference: hipsCircumference ?? this.hipsCircumference,
      underBustCircumference: underBustCircumference ?? this.underBustCircumference,
      bustCircumference: bustCircumference ?? this.bustCircumference,
      bustSpan: bustSpan ?? this.bustSpan,
      shoulderToHips: shoulderToHips ?? this.shoulderToHips,
      shoulderToKnee: shoulderToKnee ?? this.shoulderToKnee,
      shoulderToUnderBust: shoulderToUnderBust ?? this.shoulderToUnderBust,
      shoulderToBust: shoulderToBust ?? this.shoulderToBust,
      thigh: thigh ?? this.thigh,
      knee: knee ?? this.knee,
      ankle: ankle ?? this.ankle,
    );
  }

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
  };

  factory Measurement.fromJson(Map<String, dynamic> json) {
    return Measurement(
      id: json['id'] ?? '',
      customerId: json['customerId'] ?? '',
      upperBustCircumference: (json['upperBustCircumference'] ?? 0).toDouble(),
      roundShoulderCircumference: (json['roundShoulderCircumference'] ?? 0).toDouble(),
      hipsCircumference: (json['hipsCircumference'] ?? 0).toDouble(),
      underBustCircumference: (json['underBustCircumference'] ?? 0).toDouble(),
      bustCircumference: (json['bustCircumference'] ?? 0).toDouble(),
      bustSpan: (json['bustSpan'] ?? 0).toDouble(),
      shoulderToHips: (json['shoulderToHips'] ?? 0).toDouble(),
      shoulderToKnee: (json['shoulderToKnee'] ?? 0).toDouble(),
      shoulderToUnderBust: (json['shoulderToUnderBust'] ?? 0).toDouble(),
      shoulderToBust: (json['shoulderToBust'] ?? 0).toDouble(),
      thigh: (json['thigh'] ?? 0).toDouble(),
      knee: (json['knee'] ?? 0).toDouble(),
      ankle: (json['ankle'] ?? 0).toDouble(),
    );
  }
}