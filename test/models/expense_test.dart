import 'package:flutter_test/flutter_test.dart';
import 'package:reva_mobile_app/models/expense.dart';

void main() {
  group('Expense Model Tests', () {
    late Expense testExpense;
    late DateTime testDate;

    setUp(() {
      testDate = DateTime(2024, 1, 15);
      testExpense = Expense(
        id: 'expense-1',
        userId: 'user-123',
        item: 'Coffee',
        amount: 4.50,
        category: 'Food & Dining',
        date: testDate,
        createdAt: DateTime(2024, 1, 15, 10, 30),
      );
    });

    group('Expense Creation', () {
      test('should create expense with all properties', () {
        expect(testExpense.id, equals('expense-1'));
        expect(testExpense.userId, equals('user-123'));
        expect(testExpense.item, equals('Coffee'));
        expect(testExpense.amount, equals(4.50));
        expect(testExpense.category, equals('Food & Dining'));
        expect(testExpense.date, equals(testDate));
        expect(testExpense.createdAt, equals(DateTime(2024, 1, 15, 10, 30)));
      });
    });

    group('JSON Serialization', () {
      test('should serialize to JSON correctly', () {
        final json = testExpense.toJson();

        expect(json['id'], equals('expense-1'));
        expect(json['user_id'], equals('user-123'));
        expect(json['item'], equals('Coffee'));
        expect(json['amount'], equals(4.50));
        expect(json['category'], equals('Food & Dining'));
        expect(json['date'], equals(testDate.toIso8601String()));
        expect(json['created_at'], equals(DateTime(2024, 1, 15, 10, 30).toIso8601String()));
      });

      test('should deserialize from JSON correctly', () {
        final json = {
          'id': 'expense-1',
          'user_id': 'user-123',
          'item': 'Coffee',
          'amount': 4.50,
          'category': 'Food & Dining',
          'date': testDate.toIso8601String(),
          'created_at': DateTime(2024, 1, 15, 10, 30).toIso8601String(),
        };

        final expense = Expense.fromJson(json);

        expect(expense.id, equals('expense-1'));
        expect(expense.userId, equals('user-123'));
        expect(expense.item, equals('Coffee'));
        expect(expense.amount, equals(4.50));
        expect(expense.category, equals('Food & Dining'));
        expect(expense.date, equals(testDate));
        expect(expense.createdAt, equals(DateTime(2024, 1, 15, 10, 30)));
      });
    });

    group('Business Logic', () {
      test('isToday should return true for expenses from today', () {
        final todayExpense = testExpense.copyWith(date: DateTime.now());
        expect(todayExpense.isToday, isTrue);
      });

      test('isToday should return false for expenses from yesterday', () {
        final yesterdayExpense = testExpense.copyWith(
          date: DateTime.now().subtract(const Duration(days: 1)),
        );
        expect(yesterdayExpense.isToday, isFalse);
      });

      test('isThisWeek should return true for expenses from this week', () {
        final now = DateTime.now();
        final thisWeekExpense = testExpense.copyWith(date: now);
        expect(thisWeekExpense.isThisWeek, isTrue);
      });

      test('isThisMonth should return true for expenses from this month', () {
        final now = DateTime.now();
        final thisMonthExpense = testExpense.copyWith(
          date: DateTime(now.year, now.month, 15),
        );
        expect(thisMonthExpense.isThisMonth, isTrue);
      });

      test('isThisMonth should return false for expenses from last month', () {
        final now = DateTime.now();
        final lastMonthExpense = testExpense.copyWith(
          date: DateTime(now.year, now.month - 1, 15),
        );
        expect(lastMonthExpense.isThisMonth, isFalse);
      });

      test('formattedAmount should return properly formatted currency', () {
        expect(testExpense.formattedAmount, equals('\$4.50'));
        
        final expensiveItem = testExpense.copyWith(amount: 1234.56);
        expect(expensiveItem.formattedAmount, equals('\$1234.56'));
        
        final cheapItem = testExpense.copyWith(amount: 0.99);
        expect(cheapItem.formattedAmount, equals('\$0.99'));
      });

      test('formattedDate should return properly formatted date', () {
        final expense = testExpense.copyWith(date: DateTime(2024, 3, 5));
        expect(expense.formattedDate, equals('5/3/2024'));
      });
    });

    group('Common Categories', () {
      test('should have predefined common categories', () {
        expect(Expense.commonCategories, isNotEmpty);
        expect(Expense.commonCategories, contains('Food & Dining'));
        expect(Expense.commonCategories, contains('Transportation'));
        expect(Expense.commonCategories, contains('Shopping'));
        expect(Expense.commonCategories, contains('Entertainment'));
        expect(Expense.commonCategories, contains('Bills & Utilities'));
        expect(Expense.commonCategories, contains('Other'));
      });

      test('should have reasonable number of categories', () {
        expect(Expense.commonCategories.length, greaterThan(5));
        expect(Expense.commonCategories.length, lessThan(20));
      });
    });

    group('Validation', () {
      test('isValid should return true for valid expense', () {
        expect(testExpense.isValid(), isTrue);
      });

      test('isValid should return false for empty item', () {
        final invalidExpense = testExpense.copyWith(item: '');
        expect(invalidExpense.isValid(), isFalse);
      });

      test('isValid should return false for empty user ID', () {
        final invalidExpense = testExpense.copyWith(userId: '');
        expect(invalidExpense.isValid(), isFalse);
      });

      test('isValid should return false for empty expense ID', () {
        final invalidExpense = testExpense.copyWith(id: '');
        expect(invalidExpense.isValid(), isFalse);
      });

      test('isValid should return false for zero or negative amount', () {
        final zeroAmountExpense = testExpense.copyWith(amount: 0);
        expect(zeroAmountExpense.isValid(), isFalse);
        
        final negativeAmountExpense = testExpense.copyWith(amount: -5.0);
        expect(negativeAmountExpense.isValid(), isFalse);
      });

      test('isValid should return false for empty category', () {
        final invalidExpense = testExpense.copyWith(category: '');
        expect(invalidExpense.isValid(), isFalse);
      });

      test('getValidationErrors should return empty list for valid expense', () {
        final errors = testExpense.getValidationErrors();
        expect(errors, isEmpty);
      });

      test('getValidationErrors should return appropriate errors', () {
        final invalidExpense = Expense(
          id: '',
          userId: '',
          item: '',
          amount: -1.0,
          category: '',
          date: DateTime.now(),
          createdAt: DateTime.now(),
        );

        final errors = invalidExpense.getValidationErrors();
        expect(errors, contains('Expense ID cannot be empty'));
        expect(errors, contains('User ID cannot be empty'));
        expect(errors, contains('Expense item cannot be empty'));
        expect(errors, contains('Amount must be greater than 0'));
        expect(errors, contains('Category cannot be empty'));
      });

      test('getValidationErrors should check item length', () {
        final longItemExpense = testExpense.copyWith(
          item: 'a' * 201, // 201 characters
        );

        final errors = longItemExpense.getValidationErrors();
        expect(errors, contains('Expense item cannot exceed 200 characters'));
      });

      test('getValidationErrors should check category length', () {
        final longCategoryExpense = testExpense.copyWith(
          category: 'a' * 101, // 101 characters
        );

        final errors = longCategoryExpense.getValidationErrors();
        expect(errors, contains('Category cannot exceed 100 characters'));
      });

      test('getValidationErrors should check maximum amount', () {
        final expensiveExpense = testExpense.copyWith(amount: 1000000.0);

        final errors = expensiveExpense.getValidationErrors();
        expect(errors, contains('Amount cannot exceed \$999,999.99'));
      });

      test('getValidationErrors should check future dates', () {
        final futureExpense = testExpense.copyWith(
          date: DateTime.now().add(const Duration(days: 2)),
        );

        final errors = futureExpense.getValidationErrors();
        expect(errors, contains('Expense date cannot be in the future'));
      });
    });

    group('Equality and CopyWith', () {
      test('should support equality comparison', () {
        final expense1 = testExpense;
        final expense2 = Expense(
          id: 'expense-1',
          userId: 'user-123',
          item: 'Coffee',
          amount: 4.50,
          category: 'Food & Dining',
          date: testDate,
          createdAt: DateTime(2024, 1, 15, 10, 30),
        );

        expect(expense1, equals(expense2));
      });

      test('should support copyWith method', () {
        final updatedExpense = testExpense.copyWith(
          item: 'Lunch',
          amount: 12.99,
          category: 'Food & Dining',
        );

        expect(updatedExpense.id, equals(testExpense.id));
        expect(updatedExpense.item, equals('Lunch'));
        expect(updatedExpense.amount, equals(12.99));
        expect(updatedExpense.category, equals('Food & Dining'));
        expect(updatedExpense.userId, equals(testExpense.userId));
      });

      test('should have proper toString implementation', () {
        final expenseString = testExpense.toString();
        expect(expenseString, contains('Expense('));
        expect(expenseString, contains('expense-1'));
        expect(expenseString, contains('Coffee'));
        expect(expenseString, contains('\$4.50'));
        expect(expenseString, contains('Food & Dining'));
      });
    });

    group('Edge Cases', () {
      test('should handle very small amounts', () {
        final smallExpense = testExpense.copyWith(amount: 0.01);
        expect(smallExpense.isValid(), isTrue);
        expect(smallExpense.formattedAmount, equals('\$0.01'));
      });

      test('should handle amounts with many decimal places', () {
        final preciseExpense = testExpense.copyWith(amount: 4.999);
        expect(preciseExpense.formattedAmount, equals('\$5.00'));
      });

      test('should handle whitespace in item and category', () {
        final whitespaceExpense = testExpense.copyWith(
          item: '  Coffee  ',
          category: '  Food & Dining  ',
        );
        
        // Validation should still pass as we check trim()
        expect(whitespaceExpense.isValid(), isTrue);
      });
    });
  });
}