class Customer {
  int? key; // Hive key

  String name;
  String mobile;
  String rationCard;
  String aadhaar;
  String units;

  // Call tracking fields
  String callStatus;
  String? lastCalledAt;

  Customer({
    this.key,
    required this.name,
    required this.mobile,
    required this.rationCard,
    required this.aadhaar,
    required this.units,
    this.callStatus = 'Not Called',
    this.lastCalledAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'mobile': mobile,
      'rationCard': rationCard,
      'aadhaar': aadhaar,
      'units': units,
      'callStatus': callStatus,
      'lastCalledAt': lastCalledAt,
    };
  }

  factory Customer.fromMap(
    Map<String, dynamic> map, {
    int? key,
  }) {
    return Customer(
      key: key,
      name: map['name'] ?? '',
      mobile: map['mobile'] ?? '',
      rationCard: map['rationCard'] ?? '',
      aadhaar: map['aadhaar'] ?? '',
      units: map['units'] ?? '',
      callStatus: map['callStatus'] ?? 'Not Called',
      lastCalledAt: map['lastCalledAt']?.toString(),
    );
  }
}