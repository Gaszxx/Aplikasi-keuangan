enum ExpenseType { 
  modal, 
  sewa, 
  operasional, 
  gaji,      // Tambahan standar untuk upah kuli/karyawan
  lainnya    // Tambahan standar untuk pengeluaran tak terduga
}

class ExpenseModel {
  final String id;
  final ExpenseType type;
  final String unitBisnis; // KUNCI: 'Kelapa', 'Galon', 'Kontrakan', atau 'Umum'
  final double amount;
  final DateTime date;
  final String outlet;     // Lokasi spesifik: Tutugan, Capil, dll
  final String description; // KEAMANAN: Sekarang WAJIB diisi, tidak boleh kosong!

  ExpenseModel({
    required this.id,
    required this.type,
    required this.unitBisnis,
    required this.amount,
    required this.date,
    required this.outlet,
    required this.description, 
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'unitBisnis': unitBisnis,
      'amount': amount,
      'date': date.toIso8601String(),
      'outlet': outlet,
      'description': description,
    };
  }

  factory ExpenseModel.fromMap(Map<String, dynamic> data, String documentId) {
    return ExpenseModel(
      id: documentId,
      // Fallback aman: Jika data rusak di database, otomatis masuk ke 'operasional'
      type: ExpenseType.values.firstWhere(
        (e) => e.name == data['type'], 
        orElse: () => ExpenseType.operasional,
      ),
      unitBisnis: data['unitBisnis'] ?? 'Umum',
      amount: double.tryParse(data['amount'].toString()) ?? 0.0,
      date: DateTime.parse(data['date']),
      outlet: data['outlet'] ?? 'Pusat',
      description: data['description'] ?? 'Tidak ada keterangan',
    );
  }
}