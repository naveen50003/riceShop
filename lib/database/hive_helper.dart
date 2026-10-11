import 'package:hive_flutter/hive_flutter.dart';

import '../models/customer.dart';

class HiveHelper {
  static const String customersBoxName = 'customers';
  static const String masterCustomersBoxName = 'master_customers';

  static late Box customersBox;
  static late Box masterCustomersBox;

  // ------------------------------------------------------------
  // INITIALIZE HIVE
  // ------------------------------------------------------------

  static Future<void> init() async {
    await Hive.initFlutter();

    customersBox = await Hive.openBox(customersBoxName);
    masterCustomersBox = await Hive.openBox(masterCustomersBoxName);
  }

  // ============================================================
  // VIEW RECORDS
  // ============================================================

  static List<MapEntry<dynamic, Customer>> getCustomers() {
    return customersBox.toMap().entries.map((entry) {
      final map = Map<String, dynamic>.from(entry.value);

      return MapEntry(
        entry.key,
        Customer.fromMap(map),
      );
    }).toList();
  }

  static Future<dynamic> addCustomer(Customer customer) async {
    return await customersBox.add(customer.toMap());
  }

  static Future<void> updateCustomer(
    dynamic key,
    Customer customer,
  ) async {
    await customersBox.put(
      key,
      customer.toMap(),
    );
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

      return MapEntry(
        entry.key,
        Customer.fromMap(map),
      );
    }).toList();
  }

  // ------------------------------------------------------------
  // FIND MASTER CUSTOMER BY RATION CARD
  // ------------------------------------------------------------

  static MapEntry<dynamic, Customer>? getMasterByRationCard(
    String rationCard,
  ) {
    final search = rationCard.trim().toLowerCase();

    if (search.isEmpty) {
      return null;
    }

    for (final entry in masterCustomersBox.toMap().entries) {
      final map = Map<String, dynamic>.from(entry.value);

      final existingRation =
          (map['rationCard'] ?? '').toString().trim().toLowerCase();

      if (existingRation == search) {
        return MapEntry(
          entry.key,
          Customer.fromMap(map),
        );
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

  static Future<bool> saveMasterCustomer(
    Customer customer,
  ) async {
    final existing = getMasterByRationCard(
      customer.rationCard,
    );

    if (existing != null) {
      await masterCustomersBox.put(
        existing.key,
        customer.toMap(),
      );

      return true;
    }

    await masterCustomersBox.add(
      customer.toMap(),
    );

    return false;
  }

  // ------------------------------------------------------------
  // UPDATE MASTER CUSTOMER
  // ------------------------------------------------------------

  static Future<void> updateMasterCustomer(
    dynamic key,
    Customer customer,
  ) async {
    await masterCustomersBox.put(
      key,
      customer.toMap(),
    );
  }

  // ------------------------------------------------------------
  // DELETE MASTER CUSTOMER
  // ------------------------------------------------------------

  static Future<void> deleteMasterCustomer(
    dynamic key,
  ) async {
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

      final existingRationCard =
          (map['rationCard'] ?? '').toString().trim().toLowerCase();

      if (rationCard.isNotEmpty &&
          existingRationCard == rationCard) {
        // Existing record -> UPDATE
        await customersBox.put(
          entry.key,
          customer.toMap(),
        );

        return true;
      }
    }

    // New record -> INSERT
    await customersBox.add(
      customer.toMap(),
    );

    return false;
  }
}