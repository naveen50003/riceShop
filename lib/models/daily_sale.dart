class DailySale {
  final String date;
  final String rationCard;
  final String units;
  final bool isExistingCard;
  final String name;
  final bool isDeleted;
  final String? deletedAt;

  const DailySale({
    required this.date,
    required this.rationCard,
    required this.units,
    required this.isExistingCard,
    this.name = '',
    this.isDeleted = false,
    this.deletedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'rationCard': rationCard,
      'units': units,
      'isExistingCard': isExistingCard,
      'name': name,
      'isDeleted': isDeleted,
      'deletedAt': deletedAt,
    };
  }

  factory DailySale.fromMap(Map<dynamic, dynamic> map) {
    return DailySale(
      date: map['date']?.toString() ?? '',
      rationCard: map['rationCard']?.toString() ?? '',
      units: map['units']?.toString() ?? '',
      isExistingCard: map['isExistingCard'] == true,
      name: map['name']?.toString() ?? '',
      isDeleted: map['isDeleted'] == true,
      deletedAt: map['deletedAt']?.toString(),
    );
  }
}
