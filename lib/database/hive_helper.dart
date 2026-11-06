import 'package:hive_flutter/hive_flutter.dart';

import '../models/customer.dart';
import '../models/daily_sale.dart';

class HiveHelper {
  static const String customersBoxName = 'customers';
  static const String masterCustomersBoxName = 'master_customers';
  static const String missingRationCardsBoxName = 'missing_ration_cards';
  static const String dailySalesBoxName = 'daily_sales';

  static late Box customersBox;
  static late Box masterCustomersBox;
  static late Box missingRationCardsBox;
  static late Box dailySalesBox;

  // ============================================================
  // REPLACE VIEW RECORDS WITH ALL MASTER CUSTOMERS
  // ============================================================

  static Future<int> replaceViewRecordsWithMasterCustomers() async {
    // Read all master records before modifying View Records.
    final masterRecords = masterCustomersBox.values.map((record) {
      return Map<String, dynamic>.from(record as Map);
    }).toList();

    // Prevent accidentally clearing View Records if Master is empty.
    if (masterRecords.isEmpty) {
      throw Exception(
        'Master Customer List is empty. No records were transferred.',
      );
    }

    // Clear all existing operational records.
    await customersBox.clear();

    // Insert every master customer into View Records.
    for (final record in masterRecords) {
      await customersBox.add(record);
    }

    return masterRecords.length;
  }

  // ------------------------------------------------------------
  // INITIALIZE HIVE
  // ------------------------------------------------------------

  static Future<void> init() async {
    await Hive.initFlutter();

    customersBox = await Hive.openBox(customersBoxName);
    masterCustomersBox = await Hive.openBox(masterCustomersBoxName);
    missingRationCardsBox = await Hive.openBox(missingRationCardsBoxName);
    dailySalesBox = await Hive.openBox(dailySalesBoxName);
  }

  // ============================================================
  // VIEW RECORDS
  // ============================================================

  static List<MapEntry<dynamic, Customer>> getCustomers() {
    return customersBox.toMap().entries.map((entry) {
      final map = Map<String, dynamic>.from(entry.value);

      return MapEntry(entry.key, Customer.fromMap(map));
    }).toList();
  }

  static Future<void> recordDailySale(
    Customer customer, {
    bool? isExistingCard,
    DateTime? date,
  }) async {
    final rationCard = customer.rationCard.trim();
    if (rationCard.isEmpty) return;

    final saleDate = date ?? DateTime.now();
    final dateKey =
        '${saleDate.year.toString().padLeft(4, '0')}-'
        '${saleDate.month.toString().padLeft(2, '0')}-'
        '${saleDate.day.toString().padLeft(2, '0')}';
    final normalizedRationCard = rationCard.toLowerCase();
    final key = '${dateKey}_$normalizedRationCard';
    final previous = dailySalesBox.get(key);
    final wasExistingCard = previous is Map
        ? previous['isExistingCard'] == true
        : isExistingCard ?? getMasterByRationCard(rationCard) != null;

    await dailySalesBox.put(
      key,
      DailySale(
        date: dateKey,
        rationCard: rationCard,
        units: customer.units.trim(),
        isExistingCard: wasExistingCard,
        name: customer.name.trim(),
      ).toMap(),
    );
  }

  static List<DailySale> getDailySalesForDate(DateTime date) {
    final dateKey =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';

    return dailySalesBox.values
        .whereType<Map>()
        .map(DailySale.fromMap)
        .where((sale) => sale.date == dateKey)
        .toList();
  }

  static List<DailySale> getDailySalesForDateRange(
    DateTime startDate,
    DateTime endDate,
  ) {
    String dateKey(DateTime date) =>
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';

    final firstDate = dateKey(startDate);
    final lastDate = dateKey(endDate);

    final sales = dailySalesBox.values
        .whereType<Map>()
        .map(DailySale.fromMap)
        .where((sale) => sale.date.compareTo(firstDate) >= 0)
        .where((sale) => sale.date.compareTo(lastDate) <= 0)
        .toList();
    sales.sort((first, second) {
      final dateOrder = first.date.compareTo(second.date);
      return dateOrder != 0
          ? dateOrder
          : first.rationCard.compareTo(second.rationCard);
    });
    return sales;
  }

  static Future<void> deleteDailySale(
    String rationCard, {
    Customer? customer,
    DateTime? date,
  }) async {
    final saleDate = date ?? DateTime.now();
    final todayKey =
        '${saleDate.year.toString().padLeft(4, '0')}-'
        '${saleDate.month.toString().padLeft(2, '0')}-'
        '${saleDate.day.toString().padLeft(2, '0')}';
    final normalizedRationCard = rationCard.trim().toLowerCase();
    if (normalizedRationCard.isEmpty) return;

    final matchingSales =
        dailySalesBox
            .toMap()
            .entries
            .where(
              (entry) =>
                  entry.key.toString().endsWith('_$normalizedRationCard'),
            )
            .where((entry) => entry.value is Map)
            .map(
              (entry) =>
                  MapEntry(entry.key, DailySale.fromMap(entry.value as Map)),
            )
            .where((entry) => !entry.value.isDeleted)
            .toList()
          ..sort((first, second) {
            return first.value.date.compareTo(second.value.date);
          });

    final latestSale = matchingSales.isEmpty ? null : matchingSales.last;
    final key = latestSale?.key ?? '${todayKey}_$normalizedRationCard';
    final previous = dailySalesBox.get(key);
    final previousSale =
        latestSale?.value ??
        (previous is Map ? DailySale.fromMap(previous) : null);
    final dateKey = previousSale?.date ?? todayKey;

    await dailySalesBox.put(
      key,
      DailySale(
        date: dateKey,
        rationCard:
            customer?.rationCard.trim() ??
            previousSale?.rationCard ??
            rationCard.trim(),
        units: customer?.units.trim() ?? previousSale?.units ?? '',
        isExistingCard:
            previousSale?.isExistingCard ??
            getMasterByRationCard(rationCard) != null,
        name: customer?.name.trim() ?? previousSale?.name ?? '',
        isDeleted: true,
        deletedAt: DateTime.now().toIso8601String(),
      ).toMap(),
    );
  }

  static Future<dynamic> addCustomer(Customer customer) async {
    return await customersBox.add(customer.toMap());
  }

  static Future<void> updateCustomer(dynamic key, Customer customer) async {
    await customersBox.put(key, customer.toMap());
  }

  static Future<void> deleteCustomer(dynamic key) async {
    await customersBox.delete(key);
  }

  // ============================================================
  // MASTER CUSTOMER LIST
  // ============================================================

  static List<MapEntry<dynamic, Customer>> getMasterCustomers() {
    return masterCustomersBox.toMap().entries.map((entry) {
      final map = Map<String, dynamic>.from(entry.value);

      return MapEntry(entry.key, Customer.fromMap(map));
    }).toList();
  }

  // ------------------------------------------------------------
  // FIND MASTER CUSTOMER BY RATION CARD
  // ------------------------------------------------------------

  static MapEntry<dynamic, Customer>? getMasterByRationCard(String rationCard) {
    final search = rationCard.trim().toLowerCase();

    if (search.isEmpty) {
      return null;
    }

    for (final entry in masterCustomersBox.toMap().entries) {
      final map = Map<String, dynamic>.from(entry.value);

      final existingRation = (map['rationCard'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

      if (existingRation == search) {
        return MapEntry(entry.key, Customer.fromMap(map));
      }
    }

    return null;
  }

  // ------------------------------------------------------------
  // ADD OR UPDATE MASTER CUSTOMER
  //
  // Ration Card is the unique identifier.
  //
  // true  = updated existing customer
  // false = inserted new customer
  // ------------------------------------------------------------

  static Future<bool> saveMasterCustomer(Customer customer) async {
    final existing = getMasterByRationCard(customer.rationCard);

    if (existing != null) {
      await masterCustomersBox.put(existing.key, customer.toMap());

      return true;
    }

    await masterCustomersBox.add(customer.toMap());

    return false;
  }

  // ------------------------------------------------------------
  // UPDATE MASTER CUSTOMER
  // ------------------------------------------------------------

  static Future<void> updateMasterCustomer(
    dynamic key,
    Customer customer,
  ) async {
    await masterCustomersBox.put(key, customer.toMap());
  }

  // ------------------------------------------------------------
  // DELETE MASTER CUSTOMER
  // ------------------------------------------------------------

  static Future<void> deleteMasterCustomer(dynamic key) async {
    await masterCustomersBox.delete(key);
  }

  // ============================================================
  // ADD OR UPDATE VIEW RECORD
  //
  // Ration Card is used to identify an existing customer.
  //
  // true  = existing customer updated
  // false = new customer inserted
  // ============================================================

  static Future<bool> saveOrUpdate(Customer customer) async {
    final rationCard = customer.rationCard.trim().toLowerCase();

    // Search existing customer by ration card
    for (final entry in customersBox.toMap().entries) {
      final map = Map<String, dynamic>.from(entry.value);

      final existingRationCard = (map['rationCard'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

      if (rationCard.isNotEmpty && existingRationCard == rationCard) {
        // Existing record -> UPDATE
        await customersBox.put(entry.key, customer.toMap());

        return true;
      }
    }

    // New record -> INSERT
    await customersBox.add(customer.toMap());

    return false;
  }

  // ============================================================
  // UPDATE CALL STATUS
  // ============================================================

  static Future<void> updateCallTracking({
    required bool isMaster,
    required dynamic key,
    required String status,
    DateTime? lastCalledAt,
  }) async {
    final box = isMaster ? masterCustomersBox : customersBox;

    final existingValue = box.get(key);

    if (existingValue == null) {
      throw Exception('Customer record not found.');
    }

    final customerMap = Map<String, dynamic>.from(existingValue as Map);

    customerMap['callStatus'] = status;

    customerMap['lastCalledAt'] = lastCalledAt?.toIso8601String();

    await box.put(key, customerMap);
  }

  // ============================================================
  // MISSING MASTER RATION CARD NUMBERS
  // ============================================================

  static Future<void> replaceMissingRationCards(Set<String> rationCards) async {
    // The new list has already been validated by the import service.
    // Replace only the dedicated pending-list box.
    await missingRationCardsBox.clear();

    for (final rationCard in rationCards) {
      await missingRationCardsBox.put(rationCard.trim().toLowerCase(), true);
    }
  }

  static bool isMissingRationCardInExcel(String rationCard) {
    final normalized = rationCard.trim().toLowerCase();

    if (normalized.isEmpty) {
      return false;
    }

    return missingRationCardsBox.containsKey(normalized);
  }

  static int getMissingRationCardsCount() {
    return missingRationCardsBox.length;
  }
}
