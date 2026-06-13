import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'local_db_helper.dart';

class ActivationService {
  static final ActivationService instance = ActivationService._internal();
  ActivationService._internal();

  static const String _salt = "MY_STORE_SECRET_SALT_2024";

  Future<String> getRegistrationId() async {
    final db = await LocalDbHelper.instance.database;
    final List<Map<String, dynamic>> maps = await db.query('activation_info');
    
    if (maps.isNotEmpty) {
      return maps.first['registrationId'];
    }

    // Generate new Registration ID
    String deviceId = "unknown";
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      deviceId = androidInfo.id;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      deviceId = iosInfo.identifierForVendor ?? "unknown";
    }

    final bytes = utf8.encode(deviceId);
    final hash = sha256.convert(bytes);
    final registrationId = hash.toString().substring(0, 8).toUpperCase();

    await db.insert('activation_info', {
      'id': 1,
      'installDate': DateTime.now().toIso8601String(),
      'isActivated': 0,
      'registrationId': registrationId,
    });

    return registrationId;
  }

  Future<Map<String, dynamic>> getActivationStatus() async {
    final db = await LocalDbHelper.instance.database;
    final List<Map<String, dynamic>> maps = await db.query('activation_info');

    if (maps.isEmpty) {
      await getRegistrationId(); // This will create the initial record
      return await getActivationStatus();
    }

    final info = maps.first;
    bool isActivated = info['isActivated'] == 1;
    DateTime installDate = DateTime.parse(info['installDate']);
    int daysUsed = DateTime.now().difference(installDate).inDays;
    bool isTrialExpired = daysUsed >= 15;
    _lastKnownTrialStatus = isTrialExpired;

    return {
      'isActivated': isActivated,
      'daysUsed': daysUsed,
      'isTrialExpired': isTrialExpired,
      'registrationId': info['registrationId'],
      'remainingDays': 15 - daysUsed > 0 ? 15 - daysUsed : 0,
    };
  }

  bool _lastKnownTrialStatus = false;
  bool isTrialExpiredLocally() => _lastKnownTrialStatus;

  /// Returns true when app is allowed to run (activated or trial still active).
  Future<bool> canUseApp() async {
    final status = await getActivationStatus();
    return status['isActivated'] == true || status['isTrialExpired'] != true;
  }

  bool verifyKey(String registrationId, String key) {
    final bytes = utf8.encode(registrationId + _salt);
    final hash = sha256.convert(bytes);
    final expectedKey = hash.toString().substring(0, 8).toUpperCase();
    return key.toUpperCase() == expectedKey;
  }

  Future<bool> activate(String key) async {
    final status = await getActivationStatus();
    final regId = status['registrationId'];

    if (verifyKey(regId, key)) {
      final db = await LocalDbHelper.instance.database;
      await db.update(
        'activation_info',
        {'isActivated': 1, 'activationKey': key},
        where: 'id = ?',
        whereArgs: [1],
      );
      return true;
    }
    return false;
  }
}
