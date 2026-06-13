import 'dart:convert';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sqflite/sqflite.dart';
import 'backup_service.dart';
import 'local_db_helper.dart';

class SchoolDbService {
  static final SchoolDbService instance = SchoolDbService._internal();
  SchoolDbService._internal();

  final _schoolsSubject = BehaviorSubject<List<Map<String, dynamic>>>();
  final _classesSubject = BehaviorSubject<List<Map<String, dynamic>>>();
  final _studentsSubject = BehaviorSubject<List<Map<String, dynamic>>>();
  final _feesSubject = BehaviorSubject<List<Map<String, dynamic>>>();
  final _marksheetsSubject = BehaviorSubject<List<Map<String, dynamic>>>();
  final _chartsSubject = BehaviorSubject<List<Map<String, dynamic>>>();

  String get userId => FirebaseAuth.instance.currentUser?.uid ?? 'offline';

  String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(99999)}';

  Future<Database> get _db async => LocalDbHelper.instance.database;

  Future<void> refreshAll() async {
    await refreshSchools();
  }

  Future<void> _backup() async {
    try {
      await BackupService.instance.uploadBackup();
    } catch (e) {
      debugPrint('Drive backup failed: $e');
    }
  }

  Map<String, dynamic> _withId(Map<String, dynamic> row) {
    return Map<String, dynamic>.from(row);
  }

  // --- Schools ---

  Stream<List<Map<String, dynamic>>> watchSchools() => _schoolsSubject.stream;

  Future<void> refreshSchools() async {
    final db = await _db;
    final rows = await db.query(
      'schools',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'createdAt DESC',
    );
    _schoolsSubject.add(rows.map(_withId).toList());
  }

  Future<Map<String, dynamic>?> getSchool(String id) async {
    final db = await _db;
    final rows = await db.query(
      'schools',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _withId(rows.first);
  }

  Future<String> addSchool({
    required String name,
    String? address,
    String? boardName,
    String? logoPath,
  }) async {
    final db = await _db;
    final id = _newId();
    await db.insert('schools', {
      'id': id,
      'userId': userId,
      'name': name,
      'address': address ?? '',
      'boardName': boardName ?? '',
      'logoPath': logoPath,
      'createdAt': DateTime.now().toIso8601String(),
    });
    await refreshSchools();
    await _backup();
    return id;
  }

  // --- Classes ---

  Stream<List<Map<String, dynamic>>> watchClasses(String schoolId) {
    return _classesSubject.stream.map(
      (list) => list.where((c) => c['schoolId'] == schoolId).toList(),
    );
  }

  Future<void> refreshClasses(String schoolId) async {
    final db = await _db;
    final rows = await db.query(
      'classes',
      where: 'schoolId = ?',
      whereArgs: [schoolId],
      orderBy: 'name ASC, division ASC',
    );
    _classesSubject.add(
      rows.map((r) {
        final map = _withId(r);
        map['subjects'] = jsonDecode(map['subjects'] as String? ?? '[]');
        return map;
      }).toList(),
    );
  }

  Future<String> addClass({
    required String schoolId,
    required String name,
    required String division,
    String? teacherName,
    required List<String> subjects,
  }) async {
    final db = await _db;
    final id = _newId();
    await db.insert('classes', {
      'id': id,
      'schoolId': schoolId,
      'name': name,
      'division': division,
      'teacherName': teacherName ?? '',
      'subjects': jsonEncode(subjects),
      'createdAt': DateTime.now().toIso8601String(),
    });
    await refreshClasses(schoolId);
    await _backup();
    return id;
  }

  Future<Map<String, dynamic>?> getClassByNameAndDivision({
    required String schoolId,
    required String name,
    required String division,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'classes',
      where: 'schoolId = ? AND name = ? AND division = ?',
      whereArgs: [schoolId, name, division],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final map = _withId(rows.first);
    map['subjects'] = jsonDecode(map['subjects'] as String? ?? '[]');
    return map;
  }

  Future<Map<String, dynamic>?> getLastMarksheet() async {
    final db = await _db;
    final rows = await db.query(
      'marksheets',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'createdAt DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final map = _withId(rows.first);
    final data = jsonDecode(map['data'] as String) as Map<String, dynamic>;
    return {...data, 'id': map['id']};
  }

  Future<List<Map<String, dynamic>>> getStudentsByClassName(
    String className,
  ) async {
    final db = await _db;
    final rows = await db.query(
      'students',
      where: 'userId = ? AND className = ?',
      whereArgs: [userId, className],
      orderBy: 'name ASC',
    );
    return rows.map(_withId).toList();
  }

  Future<List<Map<String, dynamic>>> getClasses(String schoolId) async {
    final db = await _db;
    final rows = await db.query(
      'classes',
      where: 'schoolId = ?',
      whereArgs: [schoolId],
    );
    return rows.map((r) {
      final map = _withId(r);
      map['subjects'] = jsonDecode(map['subjects'] as String? ?? '[]');
      return map;
    }).toList();
  }

  // --- Students ---

  Stream<List<Map<String, dynamic>>> watchStudents({
    required String schoolId,
    required String className,
  }) {
    return _studentsSubject.stream.map((list) {
      return list
          .where(
            (s) => s['schoolId'] == schoolId && s['className'] == className,
          )
          .toList()
        ..sort((a, b) {
          final g = (a['gender'] as String? ?? '').compareTo(
            b['gender'] as String? ?? '',
          );
          if (g != 0) return g;
          return (a['name'] as String? ?? '').compareTo(
            b['name'] as String? ?? '',
          );
        });
    });
  }

  Future<void> refreshStudents({
    required String schoolId,
    required String className,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'students',
      where: 'userId = ? AND schoolId = ? AND className = ?',
      whereArgs: [userId, schoolId, className],
      orderBy: 'gender ASC, name ASC',
    );
    _studentsSubject.add(rows.map(_withId).toList());
  }

  Future<List<Map<String, dynamic>>> getStudents({
    required String schoolId,
    required String className,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'students',
      where: 'userId = ? AND schoolId = ? AND className = ?',
      whereArgs: [userId, schoolId, className],
      orderBy: 'gender ASC, name ASC',
    );
    return rows.map(_withId).toList();
  }

  Future<String> addStudent({
    required String schoolId,
    required String className,
    required String name,
    String? fatherName,
    String? rollNo,
    String? admNo,
    String? phone,
    String? dob,
    String? aadhaar,
    String? address,
    String? photoPath,
    required String gender,
  }) async {
    final db = await _db;
    final id = _newId();
    await db.insert('students', {
      'id': id,
      'userId': userId,
      'schoolId': schoolId,
      'className': className,
      'name': name,
      'fatherName': fatherName ?? '',
      'rollNo': rollNo ?? '',
      'admNo': admNo ?? '',
      'phone': phone ?? '',
      'dob': dob ?? '',
      'aadhaar': aadhaar ?? '',
      'address': address ?? '',
      'photoPath': photoPath,
      'gender': gender,
      'createdAt': DateTime.now().toIso8601String(),
    });
    await refreshStudents(schoolId: schoolId, className: className);
    await _backup();
    return id;
  }

  Future<void> deleteStudent(
    String id, {
    required String schoolId,
    required String className,
  }) async {
    final db = await _db;
    await db.delete('students', where: 'id = ?', whereArgs: [id]);
    await refreshStudents(schoolId: schoolId, className: className);
    await _backup();
  }

  Future<Map<String, dynamic>?> findStudentByName({
    required String name,
    required String className,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'students',
      where: 'userId = ? AND name = ? AND className = ?',
      whereArgs: [userId, name, className],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _withId(rows.first);
  }

  // --- Attendance ---

  String attendanceDocId(String schoolId, String className, DateTime date) {
    final dateStr =
        '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
    return '${userId}_${schoolId}_${className.replaceAll(' ', '_')}_$dateStr';
  }

  Future<Map<String, dynamic>> getAttendance({
    required String schoolId,
    required String className,
    required DateTime date,
  }) async {
    final db = await _db;
    final id = attendanceDocId(schoolId, className, date);
    final rows = await db.query(
      'attendance',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return {};
    final records =
        jsonDecode(rows.first['records'] as String? ?? '{}')
            as Map<String, dynamic>;
    return records.map((k, v) => MapEntry(k, v == true || v == 1));
  }

  Future<void> saveAttendance({
    required String schoolId,
    required String className,
    required DateTime date,
    required Map<String, dynamic> records,
  }) async {
    final db = await _db;
    final id = attendanceDocId(schoolId, className, date);
    await db.insert('attendance', {
      'id': id,
      'userId': userId,
      'schoolId': schoolId,
      'className': className,
      'date': date.toIso8601String(),
      'records': jsonEncode(records),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await _backup();
  }

  Future<List<Map<String, dynamic>>> getAllAttendance({
    required String schoolId,
    required String className,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'attendance',
      where: 'userId = ? AND schoolId = ? AND className = ?',
      whereArgs: [userId, schoolId, className],
    );
    return rows.map((r) {
      final map = _withId(r);
      map['records'] = jsonDecode(map['records'] as String? ?? '{}');
      return map;
    }).toList();
  }

  // --- Lessons ---

  String lessonDocId(String schoolId, String className, DateTime date) =>
      attendanceDocId(schoolId, className, date);

  Future<Map<String, dynamic>> getLessons({
    required String schoolId,
    required String className,
    required DateTime date,
  }) async {
    final db = await _db;
    final id = lessonDocId(schoolId, className, date);
    final rows = await db.query(
      'lessons',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return {};
    return jsonDecode(rows.first['records'] as String? ?? '{}')
        as Map<String, dynamic>;
  }

  Future<void> saveLessons({
    required String schoolId,
    required String className,
    required DateTime date,
    required Map<String, dynamic> records,
  }) async {
    final db = await _db;
    final id = lessonDocId(schoolId, className, date);
    await db.insert('lessons', {
      'id': id,
      'userId': userId,
      'schoolId': schoolId,
      'className': className,
      'date': date.toIso8601String(),
      'records': jsonEncode(records),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await _backup();
  }

  // --- Fees ---

  Stream<List<Map<String, dynamic>>> watchFees({
    required String schoolId,
    required String className,
  }) {
    return _feesSubject.stream.map(
      (list) => list
          .where(
            (f) => f['schoolId'] == schoolId && f['className'] == className,
          )
          .toList(),
    );
  }

  Future<void> refreshFees({
    required String schoolId,
    required String className,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'fees',
      where: 'userId = ? AND schoolId = ? AND className = ?',
      whereArgs: [userId, schoolId, className],
      orderBy: 'createdAt DESC',
    );
    _feesSubject.add(rows.map(_withId).toList());
  }

  Future<String> addFee({
    required String schoolId,
    required String className,
    required String name,
    required String amount,
  }) async {
    final db = await _db;
    final id = _newId();
    await db.insert('fees', {
      'id': id,
      'userId': userId,
      'schoolId': schoolId,
      'className': className,
      'name': name,
      'amount': amount,
      'createdAt': DateTime.now().toIso8601String(),
    });
    await refreshFees(schoolId: schoolId, className: className);
    await _backup();
    return id;
  }

  Future<void> deleteFee(
    String id, {
    required String schoolId,
    required String className,
  }) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete('fees', where: 'id = ?', whereArgs: [id]);
      await txn.delete('fee_status', where: 'feeId = ?', whereArgs: [id]);
    });
    await refreshFees(schoolId: schoolId, className: className);
    await _backup();
  }

  Future<Map<String, dynamic>> getFeeStatus(String feeId) async {
    final db = await _db;
    final rows = await db.query(
      'fee_status',
      where: 'feeId = ?',
      whereArgs: [feeId],
      limit: 1,
    );
    if (rows.isEmpty) return {};
    return jsonDecode(rows.first['records'] as String? ?? '{}')
        as Map<String, dynamic>;
  }

  Future<void> saveFeeStatus(String feeId, Map<String, dynamic> records) async {
    final db = await _db;
    await db.insert('fee_status', {
      'feeId': feeId,
      'records': jsonEncode(records),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await _backup();
  }

  // --- Marksheets ---

  Stream<List<Map<String, dynamic>>> watchMarksheets({
    required String schoolId,
    required String className,
  }) {
    return _marksheetsSubject.stream.map((list) {
      return list
          .where(
            (m) => m['schoolId'] == schoolId && m['className'] == className,
          )
          .toList()
        ..sort(
          (a, b) =>
              (b['createdAt'] as String).compareTo(a['createdAt'] as String),
        );
    });
  }

  Future<void> refreshMarksheets({
    required String schoolId,
    required String className,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'marksheets',
      where: 'userId = ? AND schoolId = ? AND className = ?',
      whereArgs: [userId, schoolId, className],
      orderBy: 'createdAt DESC',
    );
    _marksheetsSubject.add(
      rows.map((r) {
        final map = _withId(r);
        final data = jsonDecode(map['data'] as String) as Map<String, dynamic>;
        return {
          ...data,
          'id': map['id'],
          'createdAt': map['createdAt'],
          'updatedAt': map['updatedAt'],
        };
      }).toList(),
    );
  }

  Future<String> saveMarksheet(
    Map<String, dynamic> data, {
    String? docId,
  }) async {
    final db = await _db;
    final id = docId ?? _newId();
    final now = DateTime.now().toIso8601String();
    final payload = Map<String, dynamic>.from(data);
    payload.remove('id');
    payload.remove('createdAt');
    payload.remove('updatedAt');

    if (docId == null) {
      await db.insert('marksheets', {
        'id': id,
        'userId': userId,
        'schoolId': data['schoolId'],
        'className': data['className'] ?? '',
        'data': jsonEncode(payload),
        'createdAt': now,
        'updatedAt': now,
      });
    } else {
      await db.update(
        'marksheets',
        {'data': jsonEncode(payload), 'updatedAt': now},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    await refreshMarksheets(
      schoolId: data['schoolId'] as String,
      className: data['className'] as String? ?? '',
    );
    await _backup();
    return id;
  }

  Future<void> deleteMarksheet(
    String id, {
    required String schoolId,
    required String className,
  }) async {
    final db = await _db;
    await db.delete('marksheets', where: 'id = ?', whereArgs: [id]);
    await refreshMarksheets(schoolId: schoolId, className: className);
    await _backup();
  }

  Future<void> updateSchool(
    String id, {
    required String name,
    String? address,
    String? boardName,
    String? logoPath,
  }) async {
    final db = await _db;
    await db.update(
      'schools',
      {
        'name': name,
        'address': address ?? '',
        'boardName': boardName ?? '',
        'logoPath': logoPath,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    await refreshSchools();
    await _backup();
  }

  Future<void> deleteSchool(String id) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete('schools', where: 'id = ?', whereArgs: [id]);
      await txn.delete('classes', where: 'schoolId = ?', whereArgs: [id]);
      await txn.delete('students', where: 'schoolId = ?', whereArgs: [id]);
      await txn.delete('marksheets', where: 'schoolId = ?', whereArgs: [id]);
      await txn.delete('attendance', where: 'schoolId = ?', whereArgs: [id]);
      await txn.delete('lessons', where: 'schoolId = ?', whereArgs: [id]);
      await txn.delete('fees', where: 'schoolId = ?', whereArgs: [id]);
      await txn.delete('charts', where: 'schoolId = ?', whereArgs: [id]);
    });
    await refreshSchools();
    await _backup();
  }

  Future<void> updateClass(
    String id, {
    required String name,
    required String division,
    String? teacherName,
    required List<String> subjects,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'classes',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return;
    final schoolId = rows.first['schoolId'] as String;
    final oldName = rows.first['name'] as String;
    final oldDivision = rows.first['division'] as String;
    final oldClassName = '$oldName $oldDivision';
    final newClassName = '$name $division';

    await db.update(
      'classes',
      {
        'name': name,
        'division': division,
        'teacherName': teacherName ?? '',
        'subjects': jsonEncode(subjects),
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    if (oldClassName != newClassName) {
      await db.update(
        'students',
        {'className': newClassName},
        where: 'schoolId = ? AND className = ?',
        whereArgs: [schoolId, oldClassName],
      );
      await db.update(
        'marksheets',
        {'className': newClassName},
        where: 'schoolId = ? AND className = ?',
        whereArgs: [schoolId, oldClassName],
      );
      await db.update(
        'attendance',
        {'className': newClassName},
        where: 'schoolId = ? AND className = ?',
        whereArgs: [schoolId, oldClassName],
      );
      await db.update(
        'lessons',
        {'className': newClassName},
        where: 'schoolId = ? AND className = ?',
        whereArgs: [schoolId, oldClassName],
      );
      await db.update(
        'fees',
        {'className': newClassName},
        where: 'schoolId = ? AND className = ?',
        whereArgs: [schoolId, oldClassName],
      );
      await db.update(
        'charts',
        {'className': newClassName},
        where: 'schoolId = ? AND className = ?',
        whereArgs: [schoolId, oldClassName],
      );
    }

    await refreshClasses(schoolId);
    await _backup();
  }

  Future<void> deleteClass(String id) async {
    final db = await _db;
    final rows = await db.query(
      'classes',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return;
    final schoolId = rows.first['schoolId'] as String;
    final classNameName = rows.first['name'] as String;
    final classNameDivision = rows.first['division'] as String;
    final className = '$classNameName $classNameDivision';

    await db.transaction((txn) async {
      await txn.delete('classes', where: 'id = ?', whereArgs: [id]);
      await txn.delete(
        'students',
        where: 'schoolId = ? AND className = ?',
        whereArgs: [schoolId, className],
      );
      await txn.delete(
        'marksheets',
        where: 'schoolId = ? AND className = ?',
        whereArgs: [schoolId, className],
      );
      await txn.delete(
        'attendance',
        where: 'schoolId = ? AND className = ?',
        whereArgs: [schoolId, className],
      );
      await txn.delete(
        'lessons',
        where: 'schoolId = ? AND className = ?',
        whereArgs: [schoolId, className],
      );
      await txn.delete(
        'fees',
        where: 'schoolId = ? AND className = ?',
        whereArgs: [schoolId, className],
      );
      await txn.delete(
        'charts',
        where: 'schoolId = ? AND className = ?',
        whereArgs: [schoolId, className],
      );
    });

    await refreshClasses(schoolId);
    await _backup();
  }

  Future<void> updateStudent(
    String id, {
    required String name,
    String? fatherName,
    String? rollNo,
    String? admNo,
    String? phone,
    String? dob,
    String? aadhaar,
    String? address,
    String? photoPath,
    required String gender,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'students',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return;
    final schoolId = rows.first['schoolId'] as String;
    final className = rows.first['className'] as String;

    await db.update(
      'students',
      {
        'name': name,
        'fatherName': fatherName ?? '',
        'rollNo': rollNo ?? '',
        'admNo': admNo ?? '',
        'phone': phone ?? '',
        'dob': dob ?? '',
        'aadhaar': aadhaar ?? '',
        'address': address ?? '',
        'photoPath': photoPath,
        'gender': gender,
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    await refreshStudents(schoolId: schoolId, className: className);
    await _backup();
  }

  // --- Charts ---

  Stream<List<Map<String, dynamic>>> watchCharts({
    required String schoolId,
    required String className,
  }) {
    return _chartsSubject.stream.map((list) {
      return list
          .where(
            (c) => c['schoolId'] == schoolId && c['className'] == className,
          )
          .toList()
        ..sort(
          (a, b) =>
              (b['createdAt'] as String).compareTo(a['createdAt'] as String),
        );
    });
  }

  Future<void> refreshCharts({
    required String schoolId,
    required String className,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'charts',
      where: 'userId = ? AND schoolId = ? AND className = ?',
      whereArgs: [userId, schoolId, className],
      orderBy: 'createdAt DESC',
    );
    _chartsSubject.add(
      rows.map((r) {
        final map = _withId(r);
        final data = jsonDecode(map['data'] as String) as Map<String, dynamic>;
        return {
          ...data,
          'id': map['id'],
          'createdAt': map['createdAt'],
          'updatedAt': map['updatedAt'],
        };
      }).toList(),
    );
  }

  Future<String> saveChart(Map<String, dynamic> data, {String? docId}) async {
    final db = await _db;
    final id = docId ?? _newId();
    final now = DateTime.now().toIso8601String();
    final payload = Map<String, dynamic>.from(data);
    payload.remove('id');
    payload.remove('createdAt');
    payload.remove('updatedAt');

    if (docId == null) {
      await db.insert('charts', {
        'id': id,
        'userId': userId,
        'schoolId': data['schoolId'],
        'className': data['className'] ?? '',
        'data': jsonEncode(payload),
        'createdAt': now,
        'updatedAt': now,
      });
    } else {
      await db.update(
        'charts',
        {'data': jsonEncode(payload), 'updatedAt': now},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    await refreshCharts(
      schoolId: data['schoolId'] as String,
      className: data['className'] as String? ?? '',
    );
    await _backup();
    return id;
  }

  void dispose() {
    _schoolsSubject.close();
    _classesSubject.close();
    _studentsSubject.close();
    _feesSubject.close();
    _marksheetsSubject.close();
    _chartsSubject.close();
  }
}
