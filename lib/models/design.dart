class Design {
  final String id;
  final String customerId;
  final String? designFile;
  final String description;
  final DateTime createdAt;

  Design({
    required this.id,
    required this.customerId,
    this.designFile,
    required this.description,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'customerId': customerId,
    'designFile': designFile,
    'description': description,
    'createdAt': createdAt.toIso8601String(),
  };
}