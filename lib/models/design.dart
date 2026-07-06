class Design {
  final String id;
  final String customerId;
  final String? designFile;
  final String description;

  Design({
    required this.id,
    required this.customerId,
    this.designFile,
    required this.description,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'customerId': customerId,
    'designFile': designFile,
    'description': description,
  };

  factory Design.fromJson(Map<String, dynamic> json) {
    return Design(
      id: json['id'] ?? '',
      customerId: json['customerId'] ?? '',
      designFile: json['designFile'],
      description: json['description'] ?? '',
    );
  }
}