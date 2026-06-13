class ProductModel {
  String id;
  String name;
  double purchasePrice;
  double salePrice;
  double stockCount; // quantity count (pieces)
  String itemCode;
  String unit; // always 'pcs' — count only, no kg/ltr

  ProductModel({
    required this.id,
    required this.name,
    required this.purchasePrice,
    required this.salePrice,
    required this.stockCount,
    required this.itemCode,
    this.unit = 'pcs', // Default to pieces
  });

  double get unitProfit => salePrice - purchasePrice;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'purchasePrice': purchasePrice,
      'salePrice': salePrice,
      'stockCount': stockCount,
      'itemCode': itemCode,
      'unit': unit,
    };
  }

  factory ProductModel.fromMap(Map<String, dynamic> map) {
    return ProductModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      purchasePrice: (map['purchasePrice'] ?? 0.0).toDouble(),
      salePrice: (map['salePrice'] ?? 0.0).toDouble(),
      stockCount: (map['stockCount'] ?? 0.0).toDouble(),
      itemCode: map['itemCode'] ?? '',
      unit: map['unit'] ?? 'pcs',
    );
  }
}
