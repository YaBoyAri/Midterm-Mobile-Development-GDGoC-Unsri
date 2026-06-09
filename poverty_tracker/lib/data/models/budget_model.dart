class BudgetModel {
  final String id;
  final String userId;
  final String category;
  final double limitAmount;
  final String month; // format: '2026-06'

  BudgetModel({
    required this.id,
    required this.userId,
    required this.category,
    required this.limitAmount,
    required this.month,
  });

  factory BudgetModel.fromJson(Map<String, dynamic> json) {
    return BudgetModel(
      id: json['id'],
      userId: json['user_id'],
      category: json['category'],
      limitAmount: (json['limit_amount'] as num).toDouble(),
      month: json['month'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'category': category,
      'limit_amount': limitAmount,
      'month': month,
    };
  }
}