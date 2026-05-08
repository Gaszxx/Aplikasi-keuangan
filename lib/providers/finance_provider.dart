import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/income_model.dart';
import '../models/debt_model.dart';
import '../models/expense_model.dart';
import '../models/door_model.dart'; // Tambahkan import model expense

class FinanceProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  List<IncomeModel> _incomes = [];
  List<DebtModel> _debts = [];
  List<ExpenseModel> _expenses = []; // --- TAMBAHAN: List Pengeluaran ---
  List<DoorModel> _doors = [];
  List<DoorModel> get doors => _doors;
  bool _isLoading = true;

  StreamSubscription? _incomeSubscription;
  StreamSubscription? _debtSubscription;
  StreamSubscription?
  _expenseSubscription; // --- TAMBAHAN: Subscription baru ---

  List<IncomeModel> get incomes => _incomes;
  List<DebtModel> get debts => _debts;
  List<ExpenseModel> get expenses => _expenses; // --- TAMBAHAN: Getter ---
  StreamSubscription? _doorSubscription;
  bool get isLoading => _isLoading;
  bool get hasOverdueDebt {
    final now = DateTime.now();
    return _debts.any((d) => !d.isPaid && 
        (d.dueDate.isBefore(now) || 
         (d.dueDate.year == now.year && d.dueDate.month == now.month && d.dueDate.day == now.day)));
  }

  // --- KALKULASI OTOMATIS (REAL-TIME) ---
  double get totalIncome => _incomes.fold(0, (sum, item) => sum + item.amount);
  double get totalDebt =>
      _debts.where((d) => !d.isPaid).fold(0, (sum, item) => sum + item.amount);

  // --- TAMBAHAN: Kalkulasi Pengeluaran ---
  double get totalExpense =>
      _expenses.fold(0, (sum, item) => sum + item.amount);

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

    // 3. Listener Pengeluaran (Stok/Sewa)
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

    // 4. --- TAMBAHAN: Listener Pintu Kontrakan ---
    _doorSubscription = _db
        .collection('doors')
        .orderBy('roomNumber') // Mengurutkan berdasarkan nomor pintu
        .snapshots()
        .listen((snapshot) {
      _doors = snapshot.docs
          .map((doc) => DoorModel.fromMap(doc.data(), doc.id))
          .toList();
      _isLoading = false;
      notifyListeners();
    }, onError: (error) {
      debugPrint("Gagal memuat data pintu: $error");
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

  Future<void> payDebt(DebtModel debt) async {
    try {
      // 1. Catat Otomatis ke Pengeluaran (Expense) Utama
      final expense = ExpenseModel(
        id: '',
        type: ExpenseType.operasional,
        amount: debt.amount,
        date: DateTime.now(),
        outlet: 'Depot Utama', // Default
        description: debt.isInstallment 
            ? "Bayar Angsuran ${debt.creditorName} (${debt.currentInstallment}/${debt.totalInstallments})"
            : "Pelunasan Hutang: ${debt.creditorName}",
      );
      await addExpense(expense); // Memanggil fungsi expense yang sudah ada

      // 2. Update Status Hutang
      if (debt.isInstallment) {
        if (debt.currentInstallment < debt.totalInstallments) {
          // Jika masih ada sisa tenor: Naikkan angsuran & lompat bulan
          final updatedDebt = DebtModel(
            id: debt.id,
            creditorName: debt.creditorName,
            amount: debt.amount,
            dueDate: DateTime(debt.dueDate.year, debt.dueDate.month + 1, debt.dueDate.day),
            isInstallment: true,
            currentInstallment: debt.currentInstallment + 1,
            totalInstallments: debt.totalInstallments,
            isPaid: false,
            description: debt.description,
          );
          await _db.collection('debts').doc(debt.id).update(updatedDebt.toMap());
        } else {
          // Jika ini angsuran terakhir: Tandai LUNAS TOTAL
          await _db.collection('debts').doc(debt.id).update({'isPaid': true});
        }
      } else {
        // Jika hutang sekali bayar: Langsung Tandai LUNAS TOTAL
        await _db.collection('debts').doc(debt.id).update({'isPaid': true});
      }
    } catch (e) {
      debugPrint("Error payDebt: $e");
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

Future<void> addDoor(DoorModel door) async {
    try {
      await _db.collection('doors').add(door.toMap());
    } catch (e) {
      debugPrint("Error addDoor: $e");
      rethrow;
    }
  }

Future<void> updateDoor(DoorModel door) async {
    try {
      await _db.collection('doors').doc(door.id).update(door.toMap());
    } catch (e) {
      debugPrint("Error updateDoor: $e");
      rethrow;
    }
  }

  Future<void> deleteDoor(String id) async {
    try {
      await _db.collection('doors').doc(id).delete();
    } catch (e) {
      debugPrint("Error deleteDoor: $e");
      rethrow;
    }
  }

  @override
  void dispose() {
    _incomeSubscription?.cancel();
    _debtSubscription?.cancel();
    _expenseSubscription?.cancel(); // --- TAMBAHAN: Cancel subscription ---
    _doorSubscription?.cancel();
    super.dispose();
  }
}
