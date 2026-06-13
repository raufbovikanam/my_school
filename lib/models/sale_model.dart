class SaleModel {
  String id;
  DateTime date;
  List<Map<String, dynamic>> items;
  double totalAmount;
  double totalProfit;

  SaleModel({
    required this.id,
    required this.date,
    required this.items,
    required this.totalAmount,
    required this.totalProfit,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'items': items,
      'totalAmount': totalAmount,
      'totalProfit': totalProfit,
    };
  }

  factory SaleModel.fromMap(Map<String, dynamic> map) {
    return SaleModel(
      id: map['id'] ?? '',
      date: map['date'] != null ? DateTime.parse(map['date']) : DateTime.now(),
      items: List<Map<String, dynamic>>.from(map['items'] ?? []),
      totalAmount: (map['totalAmount'] ?? 0.0).toDouble(),
      totalProfit: (map['totalProfit'] ?? 0.0).toDouble(),
    );
  }
}
