class DebtModel {
  final String id;
  final String creditorName; // Nama Bank, Leasing, atau Orang (Misal: BRI, FIF, Si A)
  final double amount; // Nominal angsuran per bulan ATAU total hutang jika sekali bayar
  final DateTime dueDate; // Tanggal jatuh tempo terdekat
  final bool isInstallment; // True jika cicilan bulanan, False jika sekali bayar
  final int currentInstallment; // Angsuran ke-berapa saat ini (Misal: 3)
  final int totalInstallments; // Total tenor bulan (Misal: 12)
  final bool isPaid; // Status LUNAS TOTAL (Masuk ke tabel bawah)
  final String description; // Catatan tambahan

  DebtModel({
    required this.id,
    required this.creditorName,
    required this.amount,
    required this.dueDate,
    this.isInstallment = false,
    this.currentInstallment = 1,
    this.totalInstallments = 1,
    this.isPaid = false,
    this.description = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'creditorName': creditorName,
      'amount': amount,
      'dueDate': dueDate.toIso8601String(),
      'isInstallment': isInstallment,
      'currentInstallment': currentInstallment,
      'totalInstallments': totalInstallments,
      'isPaid': isPaid,
      'description': description,
    };
  }

  factory DebtModel.fromMap(Map<String, dynamic> data, String documentId) {
    return DebtModel(
      id: documentId,
      creditorName: data['creditorName'] ?? '',
      amount: double.tryParse(data['amount'].toString()) ?? 0.0,
      dueDate: data['dueDate'] != null ? DateTime.parse(data['dueDate'].toString()) : DateTime.now(),
      isInstallment: data['isInstallment'] ?? false,
      currentInstallment: int.tryParse(data['currentInstallment'].toString()) ?? 1,
      totalInstallments: int.tryParse(data['totalInstallments'].toString()) ?? 1,
      isPaid: data['isPaid'] ?? false,
      description: data['description'] ?? '',
    );
  }
}