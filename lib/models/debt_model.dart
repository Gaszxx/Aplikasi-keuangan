class DebtModel {
  final String id;
  final String title;       // Misal: Bank BRI, FIF Vario, Pajak Kaleng
  final String category;    // Kendaraan, Bank, Personal
  final double amount;      // Nominal utang
  final DateTime dueDate;   // Jatuh tempo
  final bool isPaid;        // Status lunas
  final DateTime? paidDate; // Tanggal dilunasi

  DebtModel({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.dueDate,
    this.isPaid = false,
    this.paidDate,
  });

  factory DebtModel.fromMap(Map<String, dynamic> data, String documentId) {
    return DebtModel(
      id: documentId,
      title: data['title'] ?? '',
      category: data['category'] ?? 'Lainnya',
      amount: (data['amount'] ?? 0).toDouble(),
      dueDate: DateTime.parse(data['dueDate']),
      isPaid: data['isPaid'] ?? false,
      paidDate: data['paidDate'] != null ? DateTime.parse(data['paidDate']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'category': category,
      'amount': amount,
      'dueDate': dueDate.toIso8601String(),
      'isPaid': isPaid,
      if (paidDate != null) 'paidDate': paidDate?.toIso8601String(),
    };
  }
}