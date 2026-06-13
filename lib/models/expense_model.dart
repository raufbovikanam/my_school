class ExpenseModel {
  String id;
  String title;
  double amount;
  DateTime date;
  String category;

  ExpenseModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.category,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'date': date.toIso8601String(),
      'category': category,
    };
  }

  factory ExpenseModel.fromMap(Map<String, dynamic> map) {
    return ExpenseModel(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      amount: (map['amount'] ?? 0.0).toDouble(),
      date: map['date'] != null ? DateTime.parse(map['date']) : DateTime.now(),
      category: map['category']?.toString() ?? 'General',
    );
  }
}
