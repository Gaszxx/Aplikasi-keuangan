import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/income_model.dart';
import '../models/debt_model.dart';

class FinanceProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  // Penyimpanan data lokal di memori aplikasi
  List<IncomeModel> _incomes = [];
  List<DebtModel> _debts = [];
  bool _isLoading = true;

  // Jalur komunikasi real-time ke Firebase
  StreamSubscription? _incomeSubscription;
  StreamSubscription? _debtSubscription;

  // Getter untuk dibaca oleh UI
  List<IncomeModel> get incomes => _incomes;
  List<DebtModel> get debts => _debts;
  bool get isLoading => _isLoading;

  // --- KALKULASI OTOMATIS ---
  double get totalIncome => _incomes.fold(0, (sum, item) => sum + item.amount);
  double get totalDebt => _debts.where((d) => !d.isPaid).fold(0, (sum, item) => sum + item.amount);
  double get netBalance => totalIncome - totalDebt; // Sisa Kas Bersih

  FinanceProvider() {
    _initStreams();
  }

  // Menyalakan pendengar (listener) real-time ke Firestore
  void _initStreams() {
    _isLoading = true;
    notifyListeners();

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
  }

  // --- FUNGSI CRUD PEMASUKAN ---
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
      debugPrint("Error deleteIncome: $e");
      rethrow;
    }
  }

  // --- FUNGSI CRUD PENGELUARAN/UTANG ---
  Future<void> addDebt(DebtModel debt) async {
    try {
      await _db.collection('debts').add(debt.toMap());
    } catch (e) {
      debugPrint("Error addDebt: $e");
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
      debugPrint("Error toggleDebtStatus: $e");
      rethrow;
    }
  }

  Future<void> deleteDebt(String id) async {
    try {
      await _db.collection('debts').doc(id).delete();
    } catch (e) {
      debugPrint("Error deleteDebt: $e");
      rethrow;
    }
  }

  // Mencegah kebocoran memori saat aplikasi ditutup
  @override
  void dispose() {
    _incomeSubscription?.cancel();
    _debtSubscription?.cancel();
    super.dispose();
  }
}