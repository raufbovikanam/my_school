import 'dart:io';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'auth_service.dart';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BackupService {
  static final BackupService instance = BackupService._internal();
  BackupService._internal();

  static const String _lastSyncKey = 'last_sync_timestamp';

  Future<String> _getDbPath() async {
    final dbPath = await getDatabasesPath();
    final user = FirebaseAuth.instance.currentUser;
    final dbName = user != null ? 'my_school_${user.uid}.db' : 'my_school.db';
    return join(dbPath, dbName);
  }

  Future<bool> _checkConnectivity() async {
    final List<ConnectivityResult> connectivityResult = await (Connectivity().checkConnectivity());
    return !connectivityResult.contains(ConnectivityResult.none);
  }

  Future<bool> uploadBackup() async {
    try {
      final httpClient = await AuthService.instance.authClient;
      if (httpClient == null) throw Exception('Google Drive account not connected');

      final driveApi = drive.DriveApi(httpClient);
      final path = await _getDbPath();
      final file = File(path);

      if (!await file.exists()) throw Exception('Database file not found');

      final dbPath = await getDatabasesPath();
      final tempBackupPath = join(dbPath, 'temp_upload.db');
      await file.copy(tempBackupPath);
      final tempFile = File(tempBackupPath);

      final driveFile = drive.File();
      driveFile.name = 'my_school_backup.db';

      final media = drive.Media(tempFile.openRead(), await tempFile.length());
      final query = "name = 'my_school_backup.db' and trashed = false";
      final fileList = await driveApi.files.list(q: query);

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        final existingFileId = fileList.files!.first.id!;
        await driveApi.files.update(driveFile, existingFileId, uploadMedia: media);
      } else {
        await driveApi.files.create(driveFile, uploadMedia: media);
      }

      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      await _updateLastSyncTimestamp();
      return true;
    } catch (e) {
      debugPrint('Upload failed: $e');
      rethrow;
    }
  }

  Future<void> _updateLastSyncTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<DateTime?> getLastSyncTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_lastSyncKey);
    return timestamp != null ? DateTime.fromMillisecondsSinceEpoch(timestamp) : null;
  }

  Future<bool> downloadRestore() async {
    try {
      final httpClient = await AuthService.instance.authClient;
      if (httpClient == null) throw Exception('Google Drive account not connected');

      final driveApi = drive.DriveApi(httpClient);
      final query = "name = 'my_school_backup.db' and trashed = false";
      final fileList = await driveApi.files.list(q: query);

      if (fileList.files == null || fileList.files!.isEmpty) return false;

      final fileId = fileList.files!.first.id!;
      final response = await driveApi.files.get(fileId, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;

      final dbPath = await getDatabasesPath();
      final localPath = await _getDbPath();
      final tempPath = join(dbPath, 'my_school_temp.db');
      
      final tempFile = File(tempPath);
      final sink = tempFile.openWrite();
      await response.stream.pipe(sink);
      await sink.close();

      final localFile = File(localPath);
      if (!await localFile.exists()) {
        await tempFile.copy(localPath);
        if (await tempFile.exists()) await tempFile.delete();
        return true;
      }

      bool success = await _mergeDatabases(tempPath, localPath);
      
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      
      return success;
    } catch (e) {
      debugPrint('Restore failed: $e');
      rethrow;
    }
  }

  Future<DateTime?> _getDriveBackupLastModifiedTime(drive.DriveApi driveApi) async {
    final query = "name = 'my_school_backup.db' and trashed = false";
    final fileList = await driveApi.files.list(q: query, $fields: 'files(id, modifiedTime)');
    if (fileList.files != null && fileList.files!.isNotEmpty) {
      return fileList.files!.first.modifiedTime;
    }
    return null;
  }

  Future<DateTime?> _getLocalDbLastModifiedTime() async {
    final path = await _getDbPath();
    final file = File(path);
    if (await file.exists()) {
      final stat = await file.stat();
      return stat.modified;
    }
    return null;
  }

  Future<void> synchronizeFiles() async {
    if (!await _checkConnectivity()) return;

    final httpClient = await AuthService.instance.authClient;
    if (httpClient == null) return;

    final driveApi = drive.DriveApi(httpClient);
    final driveModifiedTime = await _getDriveBackupLastModifiedTime(driveApi);
    final localModifiedTime = await _getLocalDbLastModifiedTime();

    try {
      if (driveModifiedTime == null && localModifiedTime != null) {
        await uploadBackup();
        return;
      }

      if (localModifiedTime == null && driveModifiedTime != null) {
        await downloadRestore();
        return;
      }

      if (driveModifiedTime != null && localModifiedTime != null) {
        if (driveModifiedTime.isAfter(localModifiedTime)) {
          await downloadRestore();
        } else if (localModifiedTime.isAfter(driveModifiedTime)) {
          await uploadBackup();
        }
      }
    } catch (e) {
      debugPrint('Sync process error: $e');
    }
  }

  Future<void> checkAndRestoreIfNeeded() async {
    final path = await _getDbPath();
    final file = File(path);

    // If local database doesn't exist, try to download from Drive
    if (!await file.exists()) {
      debugPrint('Local database missing. Attempting auto-download from Drive...');
      try {
        await downloadRestore();
      } catch (e) {
        debugPrint('Auto-download failed: $e');
      }
    }
  }

  Future<bool> _mergeDatabases(String tempPath, String localPath) async {
    Database? tempDb;
    Database? localDb;
    try {
      tempDb = await openDatabase(tempPath);
      localDb = await openDatabase(localPath);

      final tables = [
        'products', 'repairs', 'delivered_repairs', 'sales', 'expenses',
        'schools', 'classes', 'students', 'attendance', 'lessons',
        'fees', 'fee_status', 'marksheets', 'charts',
      ];
      
      for (String table in tables) {
        try {
          final List<Map<String, dynamic>> tempRecords = await tempDb.query(table);
          for (var record in tempRecords) {
            await localDb.insert(
              table, 
              record, 
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        } catch (e) {
          debugPrint('Table sync failed: $e');
        }
      }
      return true;
    } catch (e) {
      debugPrint('Merge Error: $e');
      return false;
    } finally {
      await tempDb?.close();
    }
  }
}