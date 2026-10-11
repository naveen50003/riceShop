import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/customer.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();

  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDB('customer.db');

    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  // ============================================================
  // DATABASE CREATION
  // ============================================================

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE customers(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        mobile TEXT NOT NULL,
        rationCard TEXT NULL,
        aadhaar TEXT NULL,
        units TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE master_customers(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        mobile TEXT NOT NULL,
        rationCard TEXT NOT NULL UNIQUE,
        aadhaar TEXT NULL,
        units TEXT NOT NULL
      )
    ''');
  }

  // ============================================================
  // DATABASE UPGRADE
  // ============================================================

  Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS master_customers(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          mobile TEXT NOT NULL,
          rationCard TEXT NOT NULL UNIQUE,
          aadhaar TEXT NULL,
          units TEXT NOT NULL
        )
      ''');
    }
  }

  // ============================================================
  // VIEW RECORDS - CUSTOMERS
  // ============================================================

  Future<int> insertCustomer(Customer customer) async {
    final db = await instance.database;

    print(customer.toMap());

    final id = await db.insert(
      'customers',
      customer.toMap(),
    );

    print("Inserted ID = $id");

    return id;
  }

  Future<List<Customer>> getCustomers() async {
    final db = await instance.database;

    final result = await db.query(
      'customers',
      orderBy: 'id DESC',
    );

    print("Records Found = ${result.length}");
    print(result);

    return result.map((e) => Customer.fromMap(e)).toList();
  }

  Future<int> updateCustomer(Customer customer) async {
    final db = await instance.database;

    return db.update(
      'customers',
      customer.toMap(),
      where: 'id = ?',
      whereArgs: [customer.id],
    );
  }

  Future<int> deleteCustomer(int id) async {
    final db = await instance.database;

    return db.delete(
      'customers',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ============================================================
  // MASTER CUSTOMERS
  // ============================================================

  Future<int> insertMasterCustomer(Customer customer) async {
    final db = await instance.database;

    return db.insert(
      'master_customers',
      customer.toMap(),
    );
  }

  Future<List<Customer>> getMasterCustomers() async {
    final db = await instance.database;

    final result = await db.query(
      'master_customers',
      orderBy: 'id DESC',
    );

    return result.map((e) => Customer.fromMap(e)).toList();
  }

  Future<Customer?> getMasterCustomerByRationCard(
    String rationCard,
  ) async {
    final db = await instance.database;

    final result = await db.query(
      'master_customers',
      where: 'rationCard = ?',
      whereArgs: [rationCard.trim()],
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }

    return Customer.fromMap(result.first);
  }

  Future<int> updateMasterCustomer(Customer customer) async {
    final db = await instance.database;

    return db.update(
      'master_customers',
      customer.toMap(),
      where: 'id = ?',
      whereArgs: [customer.id],
    );
  }

  Future<int> deleteMasterCustomer(int id) async {
    final db = await instance.database;

    return db.delete(
      'master_customers',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ============================================================
  // MASTER - INSERT OR UPDATE BY RATION CARD
  // ============================================================

  Future<bool> saveMasterCustomer(Customer customer) async {
    final db = await instance.database;

    final existing = await db.query(
      'master_customers',
      where: 'rationCard = ?',
      whereArgs: [customer.rationCard.trim()],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      final existingId = existing.first['id'];

      await db.update(
        'master_customers',
        customer.toMap(),
        where: 'id = ?',
        whereArgs: [existingId],
      );

      return true; // Updated
    }

    await db.insert(
      'master_customers',
      customer.toMap(),
    );

    return false; // Inserted
  }
}