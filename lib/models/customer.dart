class Customer {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String address;
  final String? profileImage;

  Customer({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    this.profileImage,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'phone': phone,
    'address': address,
    'profileImage': profileImage,
  };
}