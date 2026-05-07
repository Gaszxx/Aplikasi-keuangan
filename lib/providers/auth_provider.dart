import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum UserRole { admin, kelapa, galon, none }

class AuthProvider extends ChangeNotifier {
  UserRole _currentRole = UserRole.none;
  bool _isAuthenticated = false;

  UserRole get currentRole => _currentRole;
  bool get isAuthenticated => _isAuthenticated;

  // Standar: Hardcode kredensial untuk internal (Admin: 111111)
  final Map<String, UserRole> _validPins = {
    '111111': UserRole.admin,
    '222222': UserRole.kelapa,
    '333333': UserRole.galon,
  };

  Future<void> checkAuthStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final savedRole = prefs.getString('user_role');
    
    if (savedRole != null) {
      _currentRole = UserRole.values.firstWhere((e) => e.toString() == savedRole);
      _isAuthenticated = true;
      notifyListeners();
    }
  }

  Future<bool> login(String pin) async {
    if (_validPins.containsKey(pin)) {
      _currentRole = _validPins[pin]!;
      _isAuthenticated = true;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_role', _currentRole.toString());
      
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> logout() async {
    _currentRole = UserRole.none;
    _isAuthenticated = false;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_role');
    
    notifyListeners();
  }
}