class Measurement {
  final String id;
  final String customerId;
  final double upperBustCircumference;
  final double roundShoulderCircumference;
  final double hipsCircumference;
  final double underBustCircumference;
  final double bustCircumference;
  final double waist;
  final double shoulderToKnee;
  final double shoulderToUnderBust;
  final double shoulderToBust;
  final double thigh;
  final double knee;
  final double ankle;
  final double waistToAnkle;
  final double shoulderToAnkle;

  Measurement({
    required this.id,
    required this.customerId,
    this.upperBustCircumference = 0,
    this.roundShoulderCircumference = 0,
    this.hipsCircumference = 0,
    this.underBustCircumference = 0,
    this.bustCircumference = 0,
    this.waist = 0,
    this.shoulderToKnee = 0,
    this.shoulderToUnderBust = 0,
    this.shoulderToBust = 0,
    this.thigh = 0,
    this.knee = 0,
    this.ankle = 0,
    this.waistToAnkle = 0,
    this.shoulderToAnkle = 0,
  });

  /// A brand-new, all-zero record for [customerId], not yet saved to
  /// Firestore (hence `id: ''`). Use this the moment a customer registers
  /// or first opens the measurement screen. Once [MeasurementService]
  /// persists it, the returned [Measurement] will have a real [id].
  factory Measurement.empty(String customerId) => Measurement(
        id: '',
        customerId: customerId,
      );

  /// Whether this record has been saved to Firestore yet.
  bool get isNew => id.isEmpty;

  /// Convenience: whether the customer has entered any real data yet.
  /// Useful for showing a "complete your measurements" prompt.
  bool get isComplete =>
      ankle > 0 &&
      hipsCircumference > 0 &&
      roundShoulderCircumference > 0 &&
      shoulderToBust > 0 &&
      shoulderToKnee > 0 &&
      shoulderToUnderBust > 0 &&
      thigh > 0 &&
      underBustCircumference > 0 &&
      upperBustCircumference > 0 &&
      knee > 0 &&
      bustCircumference > 0 &&
      waist > 0 &&
      shoulderToAnkle > 0 &&
      waistToAnkle > 0;

  Measurement copyWith({
    String? id,
    String? customerId,
    double? upperBustCircumference,
    double? roundShoulderCircumference,
    double? hipsCircumference,
    double? underBustCircumference,
    double? bustCircumference,
    double? waist,
    double? shoulderToKnee,
    double? shoulderToUnderBust,
    double? shoulderToBust,
    double? thigh,
    double? knee,
    double? ankle,
    double? waistToAnkle,
    double? shoulderToAnkle,
  }) {
    return Measurement(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      upperBustCircumference: upperBustCircumference ?? this.upperBustCircumference,
      roundShoulderCircumference: roundShoulderCircumference ?? this.roundShoulderCircumference,
      hipsCircumference: hipsCircumference ?? this.hipsCircumference,
      underBustCircumference: underBustCircumference ?? this.underBustCircumference,
      bustCircumference: bustCircumference ?? this.bustCircumference,
      waist: waist ?? this.waist,
      shoulderToKnee: shoulderToKnee ?? this.shoulderToKnee,
      shoulderToUnderBust: shoulderToUnderBust ?? this.shoulderToUnderBust,
      shoulderToBust: shoulderToBust ?? this.shoulderToBust,
      thigh: thigh ?? this.thigh,
      knee: knee ?? this.knee,
      ankle: ankle ?? this.ankle,
      waistToAnkle: waistToAnkle ?? this.waistToAnkle,
      shoulderToAnkle: shoulderToAnkle ?? this.shoulderToAnkle,
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
    'waist': waist,
    'shoulderToKnee': shoulderToKnee,
    'shoulderToUnderBust': shoulderToUnderBust,
    'shoulderToBust': shoulderToBust,
    'thigh': thigh,
    'knee': knee,
    'ankle': ankle,
    'waistToAnkle': waistToAnkle,
    'shoulderToAnkle': shoulderToAnkle,
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
      waist: (json['waist'] ?? 0).toDouble(),
      shoulderToKnee: (json['shoulderToKnee'] ?? 0).toDouble(),
      shoulderToUnderBust: (json['shoulderToUnderBust'] ?? 0).toDouble(),
      shoulderToBust: (json['shoulderToBust'] ?? 0).toDouble(),
      thigh: (json['thigh'] ?? 0).toDouble(),
      knee: (json['knee'] ?? 0).toDouble(),
      ankle: (json['ankle'] ?? 0).toDouble(),
      waistToAnkle: (json['waistToAnkle'] ?? 0).toDouble(),
      shoulderToAnkle: (json['shoulderToAnkle'] ?? 0).toDouble(),
    );
  }
}