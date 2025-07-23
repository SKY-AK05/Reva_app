// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'expense.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Expense _$ExpenseFromJson(Map<String, dynamic> json) => Expense(
  id: json['id'] as String,
  userId: json['user_id'] as String,
  item: json['item'] as String,
  amount: (json['amount'] as num).toDouble(),
  category: json['category'] as String,
  date: DateTime.parse(json['date'] as String),
  createdAt: DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$ExpenseToJson(Expense instance) => <String, dynamic>{
  'id': instance.id,
  'user_id': instance.userId,
  'item': instance.item,
  'amount': instance.amount,
  'category': instance.category,
  'date': instance.date.toIso8601String(),
  'created_at': instance.createdAt.toIso8601String(),
};
