import 'package:sqflite/sqflite.dart';
import 'dart:convert';
import 'package:rxdart/rxdart.dart';
import 'package:intl/intl.dart';
import '../models/product_model.dart';
import '../models/repair_model.dart';
import '../models/expense_model.dart';
import 'local_db_helper.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._internal();
  
  final _productsSubject = BehaviorSubject<List<ProductModel>>();
  final _activeRepairsSubject = BehaviorSubject<List<RepairModel>>();
  final _repairHistorySubject = BehaviorSubject<List<RepairModel>>();
  final _expensesSubject = BehaviorSubject<List<ExpenseModel>>();
  final _salesSubject = BehaviorSubject<List<Map<String, dynamic>>>();

  DatabaseService._internal() {
    _initStreams();
  }

  factory DatabaseService() => instance;

  Future<void> refreshAll() async {
    await _initStreams();
  }

  Future<void> _initStreams() async {
    await refreshProducts();
    await refreshActiveRepairs();
    await refreshRepairHistory();
    await refreshExpenses();
    await refreshSales();
  }

  Future<Database> get _db async => await LocalDbHelper.instance.database;

  Future<void> refreshProducts() async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query('products');
    _productsSubject.add(maps.map((m) => ProductModel.fromMap(m)).toList());
  }

  Future<void> addProduct(ProductModel product) async {
    final db = await _db;
    await db.insert('products', product.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    await refreshProducts();
  }

  Future<bool> checkProductExists(String name) async {
    final db = await _db;
    final result = await db.query('products', where: 'name = ?', whereArgs: [name], limit: 1);
    return result.isNotEmpty;
  }

  Future<bool> checkItemCodeExists(String itemCode, {String? excludeId}) async {
    if (itemCode.isEmpty) return false;
    final db = await _db;
    final result = excludeId == null
        ? await db.query('products', where: 'itemCode = ?', whereArgs: [itemCode], limit: 1)
        : await db.query(
            'products',
            where: 'itemCode = ? AND id != ?',
            whereArgs: [itemCode, excludeId],
            limit: 1,
          );
    return result.isNotEmpty;
  }

  Stream<List<ProductModel>> getProducts() => _productsSubject.stream;

  Future<ProductModel?> getProductById(String id) async {
    final db = await _db;
    final maps = await db.query('products', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) return ProductModel.fromMap(maps.first);
    return null;
  }

  Future<ProductModel?> getProductByItemCode(String itemCode) async {
    final db = await _db;
    final maps = await db.query('products', where: 'itemCode = ?', whereArgs: [itemCode]);
    if (maps.isNotEmpty) return ProductModel.fromMap(maps.first);
    return null;
  }

  Future<void> updateProductStock(String productId, double newStock) async {
    final db = await _db;
    await db.update('products', {'stockCount': newStock}, where: 'id = ?', whereArgs: [productId]);
    await refreshProducts();
  }

  Future<void> deleteProduct(String id) async {
    final db = await _db;
    await db.delete('products', where: 'id = ?', whereArgs: [id]);
    await refreshProducts();
  }

  Future<void> refreshActiveRepairs() async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query('repairs', where: "status IN ('Pending', 'Ready')");
    _activeRepairsSubject.add(maps.map((m) => RepairModel.fromMap(m)).toList());
  }

  Future<void> refreshRepairHistory() async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query('delivered_repairs', orderBy: 'timestamp DESC');
    _repairHistorySubject.add(maps.map((m) {
      final details = jsonDecode(m['repairDetails']) as Map<String, dynamic>;
      return RepairModel.fromMap(details);
    }).toList());
  }

  Future<void> deleteRepairFromHistory(String serviceId) async {
    final db = await _db;
    await db.transaction((txn) async {
      // When deleting a repair from history, we should also delete its linked sale record
      await txn.delete('sales', where: 'saleId = ?', whereArgs: ['REP_SALE_$serviceId']);
      await txn.delete('delivered_repairs', where: 'serviceId = ?', whereArgs: [serviceId]);
    });
    await refreshRepairHistory();
    await refreshSales();
  }

  Future<void> addRepair(RepairModel repair) async {
    final db = await _db;
    await db.insert('repairs', repair.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    await refreshActiveRepairs();
  }

  Future<void> updateRepair(RepairModel repair) async {
    if (repair.status == 'Delivered') {
      await deliverRepair(repair, repair.totalAmount ?? 0.0);
    } else {
      final db = await _db;
      await db.update('repairs', repair.toMap(), where: 'serviceId = ?', whereArgs: [repair.serviceId]);
      await refreshActiveRepairs();
    }
  }

  Future<void> updateRepairReadyStatus(String serviceId, double total) async {
    final db = await _db;
    await db.update('repairs', {'status': 'Ready', 'totalAmount': total}, where: 'serviceId = ?', whereArgs: [serviceId]);
    await refreshActiveRepairs();
  }

  Stream<List<RepairModel>> getActiveRepairs() => _activeRepairsSubject.stream;

  Stream<List<RepairModel>> getRepairHistory() => _repairHistorySubject.stream;

  Future<RepairModel?> getRepairById(String serviceId) async {
    final db = await _db;
    final maps = await db.query('repairs', where: 'serviceId = ?', whereArgs: [serviceId]);
    if (maps.isNotEmpty) return RepairModel.fromMap(maps.first);
    return null;
  }

  /// Returns the repair from active repairs OR delivered history.
  /// [source] will be set to 'active' or 'history'.
  Future<({RepairModel repair, String source})?> findRepairAnywhere(String serviceId) async {
    final db = await _db;

    // Check active repairs first
    final activeMaps = await db.query('repairs', where: 'serviceId = ?', whereArgs: [serviceId]);
    if (activeMaps.isNotEmpty) {
      return (repair: RepairModel.fromMap(activeMaps.first), source: 'active');
    }

    // Then check delivered history
    final historyMaps = await db.query('delivered_repairs', where: 'serviceId = ?', whereArgs: [serviceId]);
    if (historyMaps.isNotEmpty) {
      return (repair: RepairModel.fromMap(historyMaps.first), source: 'history');
    }

    return null;
  }

  Future<List<String>> getActiveRepairServiceIds() async {
    final db = await _db;
    // Include both active and history IDs for scanner matching
    final activeMaps = await db.query('repairs', columns: ['serviceId']);
    final historyMaps = await db.query('delivered_repairs', columns: ['serviceId']);
    final all = [
      ...activeMaps.map((m) => m['serviceId'] as String),
      ...historyMaps.map((m) => m['serviceId'] as String),
    ];
    return all.toSet().toList();
  }

  Future<void> updateRepairPartsAndCharge(String serviceId, List parts, double serviceCharge, double totalAmount) async {
    final db = await _db;
    await db.update('repairs', {
      'parts': jsonEncode(parts),
      'serviceCharge': serviceCharge,
      'totalAmount': totalAmount,
    }, where: 'serviceId = ?', whereArgs: [serviceId]);
    await refreshActiveRepairs();
  }

  Future<void> deliverRepair(RepairModel repair, double finalAmount) async {
    final db = await _db;
    await db.transaction((txn) async {
      String yearMonth = DateTime.now().toIso8601String().substring(0, 7);
      repair.status = 'Delivered';
      repair.finalAmount = finalAmount;

      if (repair.parts.isNotEmpty) {
        // Normalize parts so calculations & reports always work.
        // Some screens store quantity as `quantity`, others as `qty`.
        final normalizedParts = repair.parts.map((item) {
          final double price = (item['price'] as num?)?.toDouble() ?? 0.0;
          final dynamic qtyRaw = item['quantity'] ?? item['qty'] ?? 1;
          final double qty = (qtyRaw as num?)?.toDouble() ?? 1.0;
          final double purchasePrice =
              (item['purchasePrice'] as num?)?.toDouble() ?? 0.0;

          return {
            'id': item['id'],
            'name': item['name'],
            'price': price,
            'purchasePrice': purchasePrice,
            'quantity': qty,
          };
        }).toList();

        // Keep repair.parts consistent for repair history/details.
        repair.parts = normalizedParts;

        final double totalPartsAmount = normalizedParts.fold(
          0.0,
          (sum, item) => sum + ((item['price'] as num?)?.toDouble() ?? 0.0) * ((item['quantity'] as num?)?.toDouble() ?? 1.0),
        );

        // `sales.items` needs `qty` key for Sale History + finance cost.
        final List<Map<String, dynamic>> salesItems = normalizedParts.map((p) {
          return {
            'id': p['id'],
            'name': p['name'],
            'price': p['price'],
            'purchasePrice': p['purchasePrice'],
            'qty': p['quantity'],
          };
        }).toList();
        await txn.insert('sales', {
          'saleId': 'REP_SALE_${repair.serviceId}',
          'items': jsonEncode(salesItems),
          'totalAmount': totalPartsAmount,
          'timestamp': DateTime.now().toIso8601String(),
          'yearMonth': yearMonth,
          'type': 'Repair Sale',
        });

        for (var part in normalizedParts) {
          final id = part['id']?.toString();
          if (id != null && id.isNotEmpty) {
            await txn.execute(
              'UPDATE products SET stockCount = stockCount - ? WHERE id = ?',
              [part['quantity'], id],
            );
          }
        }
      }

      await txn.insert('delivered_repairs', {
        'serviceId': repair.serviceId,
        'customerName': repair.customerName,
        'type': 'Repair Service',
        'totalAmount': finalAmount,
        'timestamp': DateTime.now().toIso8601String(),
        'yearMonth': yearMonth,
        'repairDetails': jsonEncode(repair.toMap()),
      });

      await txn.delete('repairs', where: 'serviceId = ?', whereArgs: [repair.serviceId]);
    });
    await refreshActiveRepairs();
    await refreshRepairHistory();
    await refreshSales();
    await refreshProducts();
  }

  Future<void> refreshSales() async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query('sales', orderBy: 'timestamp DESC');
    _salesSubject.add(maps.map((m) {
      final mutableMap = Map<String, dynamic>.from(m);
      mutableMap['items'] = jsonDecode(m['items']);
      return mutableMap;
    }).toList());
  }

  Future<void> recordSale(String id, List<Map<String, dynamic>> items, double total) async {
    final db = await _db;
    await db.transaction((txn) async {
      String yearMonth = DateTime.now().toIso8601String().substring(0, 7);
      
      await txn.insert('sales', {
        'saleId': id,
        'items': jsonEncode(items),
        'totalAmount': total,
        'timestamp': DateTime.now().toIso8601String(),
        'yearMonth': yearMonth,
        'type': 'Product Sale',
      });

      for (var item in items) {
        await txn.execute(
          'UPDATE products SET stockCount = stockCount - ? WHERE id = ?',
          [item['qty'] ?? 1, item['id']]
        );
      }
    });
    await refreshProducts();
    await refreshSales();
  }

  Future<void> deleteSale(String id) async {
    final db = await _db;
    await db.transaction((txn) async {
      // Fetch the sale to get items for stock restoration
      final sales = await txn.query('sales', where: 'saleId = ?', whereArgs: [id]);
      if (sales.isNotEmpty) {
        final sale = sales.first;
        final itemsJson = sale['items'];
        if (itemsJson is String) {
          try {
            final List<dynamic> items = jsonDecode(itemsJson);
            for (var item in items) {
              if (item is Map<String, dynamic>) {
                await txn.execute(
                  'UPDATE products SET stockCount = stockCount + ? WHERE id = ?',
                  [item['qty'] ?? 1, item['id']]
                );
              }
            }
          } catch (_) {}
        }
      }
      // Delete the sale record
      await txn.delete('sales', where: 'saleId = ?', whereArgs: [id]);
    });
    await refreshProducts();
    await refreshSales();
  }

  Stream<List<Map<String, dynamic>>> getSales() => _salesSubject.stream;

  Future<void> refreshExpenses() async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query('expenses', orderBy: 'date DESC');
    _expensesSubject.add(maps.map((m) => ExpenseModel.fromMap(m)).toList());
  }

  Future<void> addExpense(ExpenseModel expense) async {
    final db = await _db;
    await db.insert('expenses', expense.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    await refreshExpenses();
  }

  Future<void> deleteExpense(String id) async {
    final db = await _db;
    await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
    await refreshExpenses();
  }

  Stream<List<ExpenseModel>> getExpenses() => _expensesSubject.stream;

  Stream<Map<String, double>> getFinanceReport(DateTime date, {bool isMonthly = true}) {
    String filterValue = isMonthly 
        ? DateFormat('yyyy-MM').format(date)
        : DateFormat('yyyy-MM-dd').format(date);
    
    String salesQuery = isMonthly 
        ? 'yearMonth = ?' 
        : 'strftime("%Y-%m-%d", timestamp) = ?';
    
    String repairsQuery = isMonthly 
        ? 'yearMonth = ?' 
        : 'strftime("%Y-%m-%d", timestamp) = ?';
        
    String expensesQuery = isMonthly 
        ? 'strftime("%Y-%m", date) = ?' 
        : 'strftime("%Y-%m-%d", date) = ?';

    return Rx.combineLatest3(
      Stream.fromFuture(_db.then((db) => db.query('sales', where: salesQuery, whereArgs: [filterValue]))),
      Stream.fromFuture(_db.then((db) => db.query('delivered_repairs', where: repairsQuery, whereArgs: [filterValue]))),
      Stream.fromFuture(_db.then((db) => db.query('expenses', where: expensesQuery, whereArgs: [filterValue]))),
      (List<Map<String, dynamic>> sales, List<Map<String, dynamic>> repairs, List<Map<String, dynamic>> expenses) {
        double productSales = 0.0;
        double totalCost = 0.0;

        for (var item in sales) {
          final String saleType = item['type'] as String? ?? '';
          final double amount = (item['totalAmount'] as num?)?.toDouble() ?? 0.0;

          // Sales income = quick sales + repair parts (Repair Sale on deliver).
          if (saleType == 'Product Sale' || saleType == 'Repair Sale') {
            productSales += amount;
          }

          final itemsJson = item['items'];
          if (itemsJson is String) {
            try {
              final List<dynamic> decodedItems = jsonDecode(itemsJson);
              for (var saleItem in decodedItems) {
                if (saleItem is Map<String, dynamic>) {
                  final qty = ((saleItem['qty'] ?? saleItem['quantity'] ?? 1) as num)
                      .toDouble();
                  final purchasePrice =
                      ((saleItem['purchasePrice'] ?? 0) as num).toDouble();
                  totalCost += purchasePrice * qty;
                }
              }
            } catch (_) {}
          }
        }

        // Repair income = service/labor charge only (not parts).
        double totalRepairs = 0.0;
        for (var repairRow in repairs) {
          try {
            final details =
                jsonDecode(repairRow['repairDetails']) as Map<String, dynamic>;
            final double serviceCharge =
                (details['serviceCharge'] as num?)?.toDouble() ?? 0.0;
            totalRepairs += serviceCharge;
          } catch (_) {
            // Ignore broken rows, so report still works.
          }
        }
        
        double totalExpenses = expenses.fold(0.0,
            (sum, item) => sum + ((item['amount'] as num?)?.toDouble() ?? 0.0));

        double totalIncome = productSales + totalRepairs;
        double netProfit = totalIncome - totalCost - totalExpenses;

        return {
          'productSales': productSales,
          'repairRevenue': totalRepairs,
          'expenses': totalExpenses,
          'cost': totalCost,
          'totalIncome': totalIncome,
          'netProfit': netProfit,
        };
      }
    );
  }

  Stream<Map<String, double>> getMonthlyFinanceReport(DateTime date) {
    return getFinanceReport(date, isMonthly: true);
  }

  void dispose() {
    _productsSubject.close();
    _activeRepairsSubject.close();
    _repairHistorySubject.close();
    _expensesSubject.close();
    _salesSubject.close();
  }
}