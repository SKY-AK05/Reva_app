import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'expense.g.dart';

@JsonSerializable()
class Expense extends Equatable {
  final String id;
  @JsonKey(name: 'user_id')
  final String userId;
  final String item;
  final double amount;
  final String category;
  final DateTime date;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  const Expense({
    required this.id,
    required this.userId,
    required this.item,
    required this.amount,
    required this.category,
    required this.date,
    required this.createdAt,
  });

  factory Expense.fromJson(Map<String, dynamic> json) => _$ExpenseFromJson(json);
  Map<String, dynamic> toJson() => _$ExpenseToJson(this);

  Expense copyWith({
    String? id,
    String? userId,
    String? item,
    double? amount,
    String? category,
    DateTime? date,
    DateTime? createdAt,
  }) {
    return Expense(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      item: item ?? this.item,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // Business logic methods
  bool get isToday {
    final now = DateTime.now();
    return now.year == date.year && 
           now.month == date.month && 
           now.day == date.day;
  }

  bool get isThisWeek {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    
    return date.isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
           date.isBefore(endOfWeek.add(const Duration(days: 1)));
  }

  bool get isThisMonth {
    final now = DateTime.now();
    return now.year == date.year && now.month == date.month;
  }

  String get formattedAmount {
    return '\$${amount.toStringAsFixed(2)}';
  }

  String get formattedDate {
    return '${date.day}/${date.month}/${date.year}';
  }

  // Common expense categories
  static const List<String> commonCategories = [
    'Food & Dining',
    'Transportation',
    'Shopping',
    'Entertainment',
    'Bills & Utilities',
    'Healthcare',
    'Travel',
    'Education',
    'Personal Care',
    'Home & Garden',
    'Gifts & Donations',
    'Business',
    'Other',
  ];

  // Validation methods
  bool isValid() {
    return item.trim().isNotEmpty && 
           userId.trim().isNotEmpty &&
           id.trim().isNotEmpty &&
           amount > 0 &&
           category.trim().isNotEmpty;
  }

  List<String> getValidationErrors() {
    final errors = <String>[];
    
    if (id.trim().isEmpty) {
      errors.add('Expense ID cannot be empty');
    }
    
    if (userId.trim().isEmpty) {
      errors.add('User ID cannot be empty');
    }
    
    if (item.trim().isEmpty) {
      errors.add('Expense item cannot be empty');
    }
    
    if (item.length > 200) {
      errors.add('Expense item cannot exceed 200 characters');
    }
    
    if (amount <= 0) {
      errors.add('Amount must be greater than 0');
    }
    
    if (amount > 999999.99) {
      errors.add('Amount cannot exceed \$999,999.99');
    }
    
    if (category.trim().isEmpty) {
      errors.add('Category cannot be empty');
    }
    
    if (category.length > 100) {
      errors.add('Category cannot exceed 100 characters');
    }
    
    if (date.isAfter(DateTime.now().add(const Duration(days: 1)))) {
      errors.add('Expense date cannot be in the future');
    }
    
    return errors;
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        item,
        amount,
        category,
        date,
        createdAt,
      ];

  @override
  String toString() {
    return 'Expense(id: $id, item: $item, amount: $formattedAmount, category: $category)';
  }
}