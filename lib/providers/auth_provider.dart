import 'package:flutter/material.dart';

// Definisi Jabatan
enum UserRole { superadmin, admin }

class AuthProvider extends ChangeNotifier {
  // ==========================================
  // DAFTAR ADMIN & PIN (BISA DIGANTI DI SINI)
  // ==========================================
  final List<Map<String, dynamic>> registeredAdmins = [
    {
      'name': 'Bagas Sujiwo',
      'pin': '313131',
      'role': UserRole.superadmin // Bisa hapus data
    },
    {
      'name': 'Ani Nurhaeni',
      'pin': '111111',
      'role': UserRole.admin // Hanya bisa input/lihat
    },
    {
      'name': 'Ismadi',
      'pin': '222222',
      'role': UserRole.admin // Hanya bisa input/lihat
    }
  ];

  UserRole? _currentRole;
  String? _currentUserName;

  UserRole? get currentRole => _currentRole;

  // Mengambil nama user yang sedang login, jika null maka tampilkan 'GUEST'
  String get currentUserName => _currentUserName ?? 'GUEST';

  bool get isAuthenticated => _currentRole != null;

  // --- FUNGSI LOGIN ---
  bool login(String pin) {
    try {
      // Cari data admin yang PIN-nya cocok dengan yang diinput
      final admin = registeredAdmins.firstWhere((user) => user['pin'] == pin);

      // Jika ketemu, simpan data jabatannya
      _currentRole = admin['role'];
      _currentUserName = admin['name'];

      notifyListeners();
      return true; // Login sukses
    } catch (e) {
      // Jika PIN tidak ada di daftar (error dari firstWhere)
      return false; // Login gagal
    }
  }

  // --- FUNGSI LOGOUT ---
  Future<void> logout() async {
    _currentRole = null;
    _currentUserName = null;
    notifyListeners();
  }

  Future<void> checkAuthStatus() async {
    notifyListeners();
  }
}
