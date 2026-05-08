enum ExpenseType { modal, sewa, operasional }

class ExpenseModel {
  final String id;
  final ExpenseType type;
  final double amount;
  final DateTime date;
  final String outlet; // Tutugan, Capil, dll
  final String? description;

  ExpenseModel({
    required this.id,
    required this.type,
    required this.amount,
    required this.date,
    required this.outlet,
    this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'amount': amount,
      'date': date.toIso8601String(),
      'outlet': outlet,
      'description': description,
    };
  }

  factory ExpenseModel.fromMap(Map<String, dynamic> data, String documentId) {
    return ExpenseModel(
      id: documentId,
      type: ExpenseType.values.firstWhere(
        (e) => e.name == data['type'],orElse: () => ExpenseType.operasional),
      amount: double.tryParse(data['amount'].toString()) ?? 0.0,
      date: DateTime.parse(data['date']),
      outlet: data['outlet'] ?? 'Umum',
      description: data['description'],
    );
  }
}