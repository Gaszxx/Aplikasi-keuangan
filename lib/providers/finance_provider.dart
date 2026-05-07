import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/income_model.dart';
import '../models/debt_model.dart';
import '../models/expense_model.dart'; // Tambahkan import model expense

class FinanceProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  List<IncomeModel> _incomes = [];
  List<DebtModel> _debts = [];
  List<ExpenseModel> _expenses = []; // --- TAMBAHAN: List Pengeluaran ---
  bool _isLoading = true;

  StreamSubscription? _incomeSubscription;
  StreamSubscription? _debtSubscription;
  StreamSubscription? _expenseSubscription; // --- TAMBAHAN: Subscription baru ---

  List<IncomeModel> get incomes => _incomes;
  List<DebtModel> get debts => _debts;
  List<ExpenseModel> get expenses => _expenses; // --- TAMBAHAN: Getter ---
  bool get isLoading => _isLoading;

  // --- KALKULASI OTOMATIS (REAL-TIME) ---
  double get totalIncome => _incomes.fold(0, (sum, item) => sum + item.amount);
  double get totalDebt => _debts.where((d) => !d.isPaid).fold(0, (sum, item) => sum + item.amount);
  
  // --- TAMBAHAN: Kalkulasi Pengeluaran ---
  double get totalExpense => _expenses.fold(0, (sum, item) => sum + item.amount);
  
  // Sisa Kas Bersih (Sudah potong utang dan biaya operasional)
  double get netBalance => totalIncome - totalDebt - totalExpense; 

  FinanceProvider() {
    _initStreams();
  }

  void _initStreams() {
    _isLoading = true;
    notifyListeners();

    // 1. Listener Pemasukan
    _incomeSubscription = _db
        .collection('incomes')
        .orderBy('date', descending: true)
        .snapshots()
        .listen((snapshot) {
      _incomes = snapshot.docs
          .map((doc) => IncomeModel.fromMap(doc.data(), doc.id))
          .toList();
      _isLoading = false;
      notifyListeners();
    });

    // 2. Listener Utang
    _debtSubscription = _db
        .collection('debts')
        .orderBy('dueDate', descending: false)
        .snapshots()
        .listen((snapshot) {
      _debts = snapshot.docs
          .map((doc) => DebtModel.fromMap(doc.data(), doc.id))
          .toList();
      _isLoading = false;
      notifyListeners();
    });

    // 3. --- TAMBAHAN: Listener Pengeluaran (Stok/Sewa) ---
    _expenseSubscription = _db
        .collection('expenses')
        .orderBy('date', descending: true)
        .snapshots()
        .listen((snapshot) {
      _expenses = snapshot.docs
          .map((doc) => ExpenseModel.fromMap(doc.data(), doc.id))
          .toList();
      _isLoading = false;
      notifyListeners();
    }, onError: (error) {
      debugPrint("Gagal memuat data pengeluaran: $error");
      _isLoading = false;
      notifyListeners();
    });
  }

  // ==========================================
  // FUNGSI CRUD PEMASUKAN
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

  // ==========================================
  // --- TAMBAHAN: FUNGSI CRUD PENGELUARAN ---
  // ==========================================
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
  // FUNGSI CRUD PENGELUARAN / UTANG
  // ==========================================
  Future<void> addDebt(DebtModel debt) async {
    try {
      await _db.collection('debts').add(debt.toMap());
    } catch (e) {
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

  @override
  void dispose() {
    _incomeSubscription?.cancel();
    _debtSubscription?.cancel();
    _expenseSubscription?.cancel(); // --- TAMBAHAN: Cancel subscription ---
    super.dispose();
  }
}