import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _keyName = 'store_name';
  static const String _keyPhone = 'store_phone';
  static const String _keyAddress = 'store_address';

  Future<Map<String, String>> getStoreInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'name': prefs.getString(_keyName) ?? 'My Store',
      'phone': prefs.getString(_keyPhone) ?? '',
      'address': prefs.getString(_keyAddress) ?? '',
    };
  }

  Future<void> updateStoreInfo(String name, String phone, String address) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyName, name);
    await prefs.setString(_keyPhone, phone);
    await prefs.setString(_keyAddress, address);
  }
}
