class DoorModel {
  final String id;
  final String roomNumber;
  final String tenantName;
  final double monthlyPrice;
  final int dueDate; // Tanggal jatuh tempo (1-31)
  final bool isEmpty; // Status kamar kosong atau terisi
  final DateTime? lastPaymentDate; // Kapan terakhir kali dibayar

  DoorModel({
    required this.id,
    required this.roomNumber,
    required this.tenantName,
    required this.monthlyPrice,
    required this.dueDate,
    this.isEmpty = false,
    this.lastPaymentDate,
  });

  // Fungsi untuk mengubah data Object menjadi Map agar bisa disimpan ke Firebase/Database
  Map<String, dynamic> toMap() {
    return {
      'roomNumber': roomNumber,
      'tenantName': tenantName,
      'monthlyPrice': monthlyPrice,
      'dueDate': dueDate,
      'isEmpty': isEmpty,
      // Simpan format tanggal sebagai ISO string jika ada, jika tidak simpan null
      'lastPaymentDate': lastPaymentDate?.toIso8601String(),
    };
  }

  // Fungsi untuk mengubah data dari Map (Firebase) menjadi Object di Flutter
  factory DoorModel.fromMap(Map<String, dynamic> data, String documentId) {
    return DoorModel(
      id: documentId,
      roomNumber: data['roomNumber'] ?? '',
      tenantName: data['tenantName'] ?? '',
      // Parsing aman untuk angka (double)
      monthlyPrice: double.tryParse(data['monthlyPrice'].toString()) ?? 0.0,
      // Parsing aman untuk angka (int)
      dueDate: int.tryParse(data['dueDate'].toString()) ?? 1,
      isEmpty: data['isEmpty'] ?? false,
      // Cek apakah tanggal pembayaran ada di database, jika ada ubah kembali ke DateTime
      lastPaymentDate: data['lastPaymentDate'] != null 
          ? DateTime.tryParse(data['lastPaymentDate'].toString()) 
          : null,
    );
  }
}