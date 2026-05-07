enum IncomeType { kelapa, galon, kontrakan }

class IncomeModel {
  final String id;
  final IncomeType type;
  final double amount; // Pendapatan bersih atau jumlah bayar
  final DateTime date;
  final String submittedBy; // Role yang menginput (Admin/Karyawan)

  // Field spesifik (bersifat opsional/nullable tergantung bisnisnya)
  final String? location;    // Untuk Kelapa (Tempat A, B)
  final double? grossAmount; // Untuk Kelapa (Kotor)
  final double? employeeCut; // Untuk Kelapa (Potongan Gaji)
  final String? doorNumber;  // Untuk Kontrakan (Pintu No)

  IncomeModel({
    required this.id,
    required this.type,
    required this.amount,
    required this.date,
    required this.submittedBy,
    this.location,
    this.grossAmount,
    this.employeeCut,
    this.doorNumber,
  });

  // Fungsi untuk mengubah data dari Firebase menjadi objek Dart
  factory IncomeModel.fromMap(Map<String, dynamic> data, String documentId) {
    return IncomeModel(
      id: documentId,
      type: IncomeType.values.firstWhere((e) => e.name == data['type']),
      amount: (data['amount'] ?? 0).toDouble(),
      date: DateTime.parse(data['date']),
      submittedBy: data['submittedBy'] ?? '',
      location: data['location'],
      grossAmount: data['grossAmount']?.toDouble(),
      employeeCut: data['employeeCut']?.toDouble(),
      doorNumber: data['doorNumber'],
    );
  }

  // Fungsi untuk mengirim data dari Dart ke Firebase
  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'amount': amount,
      'date': date.toIso8601String(),
      'submittedBy': submittedBy,
      if (location != null) 'location': location,
      if (grossAmount != null) 'grossAmount': grossAmount,
      if (employeeCut != null) 'employeeCut': employeeCut,
      if (doorNumber != null) 'doorNumber': doorNumber,
    };
  }
}