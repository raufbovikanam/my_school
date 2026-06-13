import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LocalDbHelper {
  static final LocalDbHelper instance = LocalDbHelper._init();
  static Database? _database;

  LocalDbHelper._init();

  Future<Database> get database async {
    final user = FirebaseAuth.instance.currentUser;
    final dbName = user != null ? 'my_school_${user.uid}.db' : 'my_school.db';
    
    if (_database != null) {
      // If user changed, close and reopen
      if (basename(_database!.path) != dbName) {
        await closeDatabase();
      } else {
        return _database!;
      }
    }
    
    _database = await _initDB(dbName);
    return _database!;
  }

  Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 6,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE products ADD COLUMN unit TEXT DEFAULT "pcs"');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE sales ADD COLUMN yearMonth TEXT DEFAULT ""');
      await db.execute('ALTER TABLE delivered_repairs ADD COLUMN yearMonth TEXT DEFAULT ""');
      
      var salesRecords = await db.query('sales');
      for (var record in salesRecords) {
        var timestamp = record['timestamp'] as String;
        var date = DateTime.parse(timestamp);
        var ym = DateFormat('yyyy-MM').format(date);
        await db.update('sales', {'yearMonth': ym}, where: 'saleId = ?', whereArgs: [record['saleId']]);
      }
      
      var repairRecords = await db.query('delivered_repairs');
      for (var record in repairRecords) {
        var timestamp = record['timestamp'] as String;
        var date = DateTime.parse(timestamp);
        var ym = DateFormat('yyyy-MM').format(date);
        await db.update('delivered_repairs', {'yearMonth': ym}, where: 'serviceId = ?', whereArgs: [record['serviceId']]);
      }
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE expenses ADD COLUMN title TEXT DEFAULT ""');
    }
    if (oldVersion < 5) {
      // Adding missing columns for RepairModel compatibility
      await db.execute('ALTER TABLE repairs ADD COLUMN phone TEXT DEFAULT ""');
      await db.execute('ALTER TABLE repairs ADD COLUMN cycleModel TEXT DEFAULT ""');
      await db.execute('ALTER TABLE repairs ADD COLUMN complaint TEXT DEFAULT ""');
      await db.execute('ALTER TABLE repairs ADD COLUMN serviceCharge REAL DEFAULT 0.0');
      await db.execute('ALTER TABLE repairs ADD COLUMN parts TEXT DEFAULT "[]"');
      await db.execute('ALTER TABLE repairs ADD COLUMN date TEXT DEFAULT ""');
      await db.execute('ALTER TABLE repairs ADD COLUMN advance REAL DEFAULT 0.0');
      await db.execute('ALTER TABLE repairs ADD COLUMN billNumber TEXT');
      await db.execute('ALTER TABLE repairs ADD COLUMN mechanicName TEXT');
    }
    if (oldVersion < 6) {
      await _createSchoolTables(db);
    }
  }

  Future<void> _createSchoolTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS schools (
        id TEXT PRIMARY KEY,
        userId TEXT NOT NULL,
        name TEXT NOT NULL,
        address TEXT,
        boardName TEXT,
        logoPath TEXT,
        createdAt TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS classes (
        id TEXT PRIMARY KEY,
        schoolId TEXT NOT NULL,
        name TEXT NOT NULL,
        division TEXT NOT NULL,
        teacherName TEXT,
        subjects TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS students (
        id TEXT PRIMARY KEY,
        userId TEXT NOT NULL,
        schoolId TEXT NOT NULL,
        className TEXT NOT NULL,
        name TEXT NOT NULL,
        fatherName TEXT,
        rollNo TEXT,
        admNo TEXT,
        phone TEXT,
        dob TEXT,
        aadhaar TEXT,
        address TEXT,
        photoPath TEXT,
        gender TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS attendance (
        id TEXT PRIMARY KEY,
        userId TEXT NOT NULL,
        schoolId TEXT NOT NULL,
        className TEXT NOT NULL,
        date TEXT NOT NULL,
        records TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS lessons (
        id TEXT PRIMARY KEY,
        userId TEXT NOT NULL,
        schoolId TEXT NOT NULL,
        className TEXT NOT NULL,
        date TEXT NOT NULL,
        records TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS fees (
        id TEXT PRIMARY KEY,
        userId TEXT NOT NULL,
        schoolId TEXT NOT NULL,
        className TEXT NOT NULL,
        name TEXT NOT NULL,
        amount TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS fee_status (
        feeId TEXT PRIMARY KEY,
        records TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS marksheets (
        id TEXT PRIMARY KEY,
        userId TEXT NOT NULL,
        schoolId TEXT NOT NULL,
        className TEXT NOT NULL,
        data TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS charts (
        id TEXT PRIMARY KEY,
        userId TEXT NOT NULL,
        schoolId TEXT NOT NULL,
        className TEXT NOT NULL,
        data TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        purchasePrice REAL NOT NULL,
        salePrice REAL NOT NULL,
        stockCount REAL NOT NULL,
        itemCode TEXT UNIQUE,
        unit TEXT DEFAULT "pcs"
      )
    ''');

    await db.execute('''
      CREATE TABLE repairs (
        serviceId TEXT PRIMARY KEY,
        customerName TEXT NOT NULL,
        phone TEXT,
        cycleModel TEXT,
        complaint TEXT,
        serviceCharge REAL,
        parts TEXT,
        status TEXT NOT NULL,
        date TEXT NOT NULL,
        advance REAL,
        finalAmount REAL,
        totalAmount REAL,
        billNumber TEXT,
        mechanicName TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE delivered_repairs (
        serviceId TEXT PRIMARY KEY,
        customerName TEXT NOT NULL,
        type TEXT NOT NULL,
        totalAmount REAL NOT NULL,
        timestamp TEXT NOT NULL,
        yearMonth TEXT NOT NULL,
        repairDetails TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sales (
        saleId TEXT PRIMARY KEY,
        items TEXT NOT NULL,
        totalAmount REAL NOT NULL,
        timestamp TEXT NOT NULL,
        yearMonth TEXT NOT NULL,
        type TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE expenses (
        id TEXT PRIMARY KEY,
        title TEXT,
        category TEXT NOT NULL,
        amount REAL NOT NULL,
        description TEXT,
        date TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE activation_info (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        installDate TEXT NOT NULL,
        isActivated INTEGER DEFAULT 0,
        activationKey TEXT,
        registrationId TEXT NOT NULL
      )
    ''');

    await _createSchoolTables(db);
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}