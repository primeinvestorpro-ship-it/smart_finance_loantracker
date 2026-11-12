import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static final AuthService instance = AuthService._internal();
  AuthService._internal();

  static const String _keyPhone = 'auth_phone';
  static const String _keyMpinHash = 'auth_mpin_hash';
  static const String _keyIsLoggedIn = 'auth_is_logged_in';

  /// Hash MPIN with SHA-256 for secure local storage
  String _hashMpin(String mpin) {
    return sha256.convert(utf8.encode(mpin.trim())).toString();
  }

  /// Check if user has registered Phone & MPIN
  Future<bool> isUserRegistered() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString(_keyPhone);
    final hash = prefs.getString(_keyMpinHash);
    return phone != null && phone.isNotEmpty && hash != null && hash.isNotEmpty;
  }

  /// Check current session status
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsLoggedIn) ?? false;
  }

  /// Get registered phone number (masked)
  Future<String> getMaskedPhoneNumber() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString(_keyPhone) ?? '';
    if (phone.length >= 10) {
      return '${phone.substring(0, 2)}******${phone.substring(phone.length - 2)}';
    }
    return phone;
  }

  /// Setup / Register new Phone and 4-digit MPIN
  Future<bool> register({required String phone, required String mpin}) async {
    if (phone.trim().length < 10 || mpin.trim().length < 4) return false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPhone, phone.trim());
    await prefs.setString(_keyMpinHash, _hashMpin(mpin));
    await prefs.setBool(_keyIsLoggedIn, true);
    return true;
  }

  /// Validate MPIN and unlock app session
  Future<bool> loginWithMpin(String mpin) async {
    final prefs = await SharedPreferences.getInstance();
    final savedHash = prefs.getString(_keyMpinHash);
    if (savedHash == null) return false;

    final inputHash = _hashMpin(mpin);
    if (savedHash == inputHash) {
      await prefs.setBool(_keyIsLoggedIn, true);
      return true;
    }
    return false;
  }

  /// Logout and lock the session
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, false);
  }
}
