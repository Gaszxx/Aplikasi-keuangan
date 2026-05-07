import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // Untuk debugPrint


enum IncomeType { kelapa, galon, kontrakan }

class IncomeModel {
  final String id;
  final IncomeType type;
  
  /// [amount] adalah PENDAPATAN BERSIH (Net Income) yang masuk ke laci/rekening.
  /// Rumus Kelapa: grossAmount - capitalCost - employeeCut - rentCost
  final double amount; 
  
  final DateTime date;
  final String submittedBy; // Role yang menginput (Admin/Karyawan)
  final String? description; // Catatan tambahan (Penting untuk audit ERP)

  // --- FIELD SPESIFIK BISNIS (Opsional/Nullable) ---
  
  // 1. Khusus Kelapa (Manajemen Operasional & HPP)
  final String? location;      // Lokasi Lapak (Tempat A, B)
  final double? grossAmount;   // Pendapatan Kotor (Uang dari pelanggan)
  final double? capitalCost;   // Modal Barang / HPP (Misal: beli 500 pcs kelapa)
  final double? employeeCut;   // Potongan Gaji Karyawan (Bisa 15% atau custom)
  final double? rentCost;      // Pembayaran Sewa Tempat (Jika sedang waktunya bayar)
  final int? itemQuantity;     // Jumlah barang yang berhubungan (Misal: 500 pcs)

  // 2. Khusus Kontrakan
  final String? doorNumber;    // Nomor Pintu Kontrakan

  IncomeModel({
    required this.id,
    required this.type,
    required this.amount,
    required this.date,
    required this.submittedBy,
    this.description,
    this.location,
    this.grossAmount,
    this.capitalCost,
    this.employeeCut,
    this.rentCost,
    this.itemQuantity,
    this.doorNumber,
  });

  // Fungsi untuk mengubah data dari Firebase menjadi objek Dart
// Fungsi untuk mengubah data dari Firebase menjadi objek Dart
// Fungsi untuk mengubah data dari Firebase menjadi objek Dart (MODE ANTI-CRASH)
  factory IncomeModel.fromMap(Map<String, dynamic> data, String documentId) {
    try {
      // 1. Penanganan Tanggal Ekstra Aman (Bisa String, bisa Timestamp)
      DateTime parsedDate = DateTime.now();
      if (data['date'] != null) {
        if (data['date'] is Timestamp) {
          parsedDate = (data['date'] as Timestamp).toDate();
        } else {
          parsedDate = DateTime.tryParse(data['date'].toString()) ?? DateTime.now();
        }
      }

      // 2. Parsing Data Utama
      return IncomeModel(
        id: documentId,
        type: IncomeType.values.firstWhere(
          (e) => e.name == data['type'], 
          orElse: () => IncomeType.kelapa // Fallback
        ),
        amount: double.tryParse(data['amount']?.toString() ?? '0') ?? 0.0,
        date: parsedDate,
        submittedBy: data['submittedBy']?.toString() ?? 'Unknown',
        description: data['description']?.toString(),
        
        // Data Operasional
        location: data['location']?.toString(),
        grossAmount: data['grossAmount'] != null ? double.tryParse(data['grossAmount'].toString()) : null,
        capitalCost: data['capitalCost'] != null ? double.tryParse(data['capitalCost'].toString()) : null,
        employeeCut: data['employeeCut'] != null ? double.tryParse(data['employeeCut'].toString()) : null,
        rentCost: data['rentCost'] != null ? double.tryParse(data['rentCost'].toString()) : null,
        itemQuantity: data['itemQuantity'] != null ? int.tryParse(data['itemQuantity'].toString()) : null,
        
        doorNumber: data['doorNumber']?.toString(),
      );
      
    } catch (e) {
      // 3. JIKA ADA DATA RUSAK, JANGAN CRASH! Tampilkan sebagai "Data Error"
      debugPrint('CRITICAL ERROR: Gagal membaca dokumen $documentId -> $e');
      return IncomeModel(
        id: documentId,
        type: IncomeType.kelapa,
        amount: 0.0,
        date: DateTime.now(),
        submittedBy: 'System Error',
        description: '⚠️ DATA RUSAK: Hubungi Developer',
      );
    }
  }

  // Fungsi untuk mengirim data dari Dart ke Firebase
  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'amount': amount,
      'date': date.toIso8601String(),
      'submittedBy': submittedBy,
      if (description != null && description!.isNotEmpty) 'description': description,
      
      // Data Operasional
      if (location != null) 'location': location,
      if (grossAmount != null) 'grossAmount': grossAmount,
      if (capitalCost != null) 'capitalCost': capitalCost,
      if (employeeCut != null) 'employeeCut': employeeCut,
      if (rentCost != null) 'rentCost': rentCost,
      if (itemQuantity != null) 'itemQuantity': itemQuantity,
      
      if (doorNumber != null) 'doorNumber': doorNumber,
    };
  }
}