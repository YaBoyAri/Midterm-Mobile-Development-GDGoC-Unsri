class BillModel {
  final String id;
  final String userId;
  final String name;
  final double amount;
  final DateTime dueDate;
  final bool isPaid;

  BillModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.amount,
    required this.dueDate,
    required this.isPaid,
  });

  factory BillModel.fromJson(Map<String, dynamic> json) {
    return BillModel(
      id: json['id'],
      userId: json['user_id'],
      name: json['name'],
      amount: (json['amount'] as num).toDouble(),
      dueDate: DateTime.parse(json['due_date']),
      isPaid: json['is_paid'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'name': name,
      'amount': amount,
      'due_date': dueDate.toIso8601String().split('T')[0],
      'is_paid': isPaid,
    };
  }
}