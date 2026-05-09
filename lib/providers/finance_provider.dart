import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/income_model.dart';
import '../models/debt_model.dart';
import '../models/expense_model.dart';
import '../models/door_model.dart';

class FinanceProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  List<IncomeModel> _incomes = [];
  List<DebtModel> _debts = [];
  List<ExpenseModel> _expenses = [];
  List<DoorModel> _doors = [];
  bool _isLoading = true;

  // Menggunakan List untuk mencegah memory leak dan mempermudah dispose
  final List<StreamSubscription?> _streams = [];

  List<IncomeModel> get incomes => _incomes;
  List<DebtModel> get debts => _debts;
  List<ExpenseModel> get expenses => _expenses;
  List<DoorModel> get doors => _doors;
  bool get isLoading => _isLoading;

  // --- FINANCIAL METRICS ---
  double get totalIncome => _incomes.fold(0.0, (sum, item) => sum + item.amount);
  double get totalExpense => _expenses.fold(0.0, (sum, item) => sum + item.amount);
  
  // Kas Bersih Unit Bisnis (Tidak dipotong hutang pribadi)
  double get netBalance => totalIncome - totalExpense;
  
  double get totalOutstandingDebt => _debts.where((d) => !d.isPaid).fold(0.0, (sum, item) => sum + item.amount);

  bool get hasOverdueDebt {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _debts.any((d) => !d.isPaid && (d.dueDate.isBefore(today) || d.dueDate.isAtSameMomentAs(today)));
  }

  FinanceProvider() {
    _initStreams();
  }

  void _initStreams() {
    _isLoading = true;
    
    for (var stream in _streams) {
      stream?.cancel();
    }
    _streams.clear();

    _streams.add(_db.collection('incomes').orderBy('date', descending: true).snapshots().listen((snap) {
      _incomes = snap.docs.map((doc) => IncomeModel.fromMap(doc.data(), doc.id)).toList();
      _isLoading = false;
      notifyListeners();
    }));

    _streams.add(_db.collection('debts').orderBy('dueDate', descending: false).snapshots().listen((snap) {
      _debts = snap.docs.map((doc) => DebtModel.fromMap(doc.data(), doc.id)).toList();
      notifyListeners();
    }));

    _streams.add(_db.collection('expenses').orderBy('date', descending: true).snapshots().listen((snap) {
      _expenses = snap.docs.map((doc) => ExpenseModel.fromMap(doc.data(), doc.id)).toList();
      notifyListeners();
    }));

    _streams.add(_db.collection('doors').orderBy('roomNumber').snapshots().listen((snap) {
      _doors = snap.docs.map((doc) => DoorModel.fromMap(doc.data(), doc.id)).toList();
      notifyListeners();
    }));
  }

  // ==========================================
  // CRUD PEMASUKAN & PENGELUARAN
  // ==========================================
  Future<void> addIncome(IncomeModel income) async {
    try {
      await _db.collection('incomes').add(income.toMap());
    } catch (e) {
      debugPrint("Error addIncome: $e");
      rethrow;
    }
  }

  Future<void> deleteIncome(String id) async {
    try {
      await _db.collection('incomes').doc(id).delete();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> addExpense(ExpenseModel expense) async {
    try {
      await _db.collection('expenses').add(expense.toMap());
    } catch (e) {
      debugPrint("Error addExpense: $e");
      rethrow;
    }
  }

  Future<void> deleteExpense(String id) async {
    try {
      await _db.collection('expenses').doc(id).delete();
    } catch (e) {
      rethrow;
    }
  }

  // ==========================================
  // LOGIKA HUTANG (DANA PRIBADI BOS)
  // ==========================================
  Future<void> addDebt(DebtModel debt) async {
    try {
      await _db.collection('debts').add(debt.toMap());
    } catch (e) {
      rethrow;
    }
  }

  Future<void> payDebt(DebtModel debt) async {
    try {
      final debtRef = _db.collection('debts').doc(debt.id);

      if (debt.isInstallment && debt.currentInstallment < debt.totalInstallments) {
        // Lanjut ke angsuran bulan berikutnya
        await debtRef.update({
          'currentInstallment': debt.currentInstallment + 1,
          'dueDate': DateTime(debt.dueDate.year, debt.dueDate.month + 1, debt.dueDate.day).toIso8601String(),
        });
      } else {
        // Lunas total
        await debtRef.update({
          'isPaid': true,
          'paidDate': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint("Error payDebt: $e");
      rethrow;
    }
  }

  Future<void> toggleDebtStatus(String id, bool currentStatus) async {
    try {
      await _db.collection('debts').doc(id).update({
        'isPaid': !currentStatus,
        'paidDate': !currentStatus ? DateTime.now().toIso8601String() : null,
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteDebt(String id) async {
    try {
      await _db.collection('debts').doc(id).delete();
    } catch (e) {
      rethrow;
    }
  }

  // ==========================================
  // CRUD KONTRAKAN (DOORS)
  // ==========================================
  Future<void> addDoor(DoorModel door) async {
    try {
      await _db.collection('doors').add(door.toMap());
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateDoor(DoorModel door) async {
    try {
      await _db.collection('doors').doc(door.id).update(door.toMap());
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteDoor(String id) async {
    try {
      await _db.collection('doors').doc(id).delete();
    } catch (e) {
      rethrow;
    }
  }

  @override
  void dispose() {
    for (var stream in _streams) {
      stream?.cancel();
    }
    super.dispose();
  }
}