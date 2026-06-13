class RepairModel {
  String serviceId;
  String customerName;
  String phone;
  String cycleModel;
  String complaint;
  double serviceCharge;
  List<dynamic> parts;
  String status;
  DateTime date;
  double advance;
  double finalAmount;
  double? totalAmount;
  String? billNumber;
  String? mechanicName;

  RepairModel({
    required this.serviceId,
    required this.customerName,
    required this.phone,
    required this.cycleModel,
    required this.complaint,
    this.serviceCharge = 0.0,
    this.parts = const [],
    this.status = 'Pending',
    required this.date,
    this.advance = 0.0,
    this.finalAmount = 0.0,
    this.totalAmount,
    this.billNumber,
    this.mechanicName,
  });

  Map<String, dynamic> toMap() {
    return {
      'serviceId': serviceId,
      'customerName': customerName,
      'phone': phone,
      'cycleModel': cycleModel,
      'complaint': complaint,
      'serviceCharge': serviceCharge,
      'parts': parts,
      'status': status,
      'date': date.toIso8601String(),
      'advance': advance,
      'finalAmount': finalAmount,
      'totalAmount': totalAmount,
      'billNumber': billNumber,
      'mechanicName': mechanicName,
    };
  }

  factory RepairModel.fromMap(Map<String, dynamic> map) {
    return RepairModel(
      serviceId: map['serviceId'] ?? '',
      customerName: map['customerName'] ?? '',
      phone: map['phone'] ?? '',
      cycleModel: map['cycleModel'] ?? '',
      complaint: map['complaint'] ?? '',
      serviceCharge: (map['serviceCharge'] ?? 0.0).toDouble(),
      parts: List<dynamic>.from(map['parts'] ?? []),
      status: map['status'] ?? 'Pending',
      date: map['date'] != null ? DateTime.parse(map['date']) : DateTime.now(),
      advance: (map['advance'] ?? 0.0).toDouble(),
      finalAmount: (map['finalAmount'] ?? 0.0).toDouble(),
      totalAmount: map['totalAmount'] != null ? (map['totalAmount'] as num).toDouble() : null,
      billNumber: map['billNumber'],
      mechanicName: map['mechanicName'],
    );
  }
}
