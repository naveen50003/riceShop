class Customer {
  int? key; // Hive key

  String name;
  String mobile;
  String rationCard;
  String aadhaar;
  String units;

  Customer({
    this.key,
    required this.name,
    required this.mobile,
    required this.rationCard,
    required this.aadhaar,
    required this.units,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'mobile': mobile,
      'rationCard': rationCard,
      'aadhaar': aadhaar,
      'units': units,
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map, {int? key}) {
    return Customer(
      key: key,
      name: map['name'] ?? '',
      mobile: map['mobile'] ?? '',
      rationCard: map['rationCard'] ?? '',
      aadhaar: map['aadhaar'] ?? '',
      units: map['units'] ?? '',
    );
  }
}