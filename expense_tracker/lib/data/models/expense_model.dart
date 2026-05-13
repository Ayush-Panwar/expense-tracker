import 'package:drift/drift.dart';
import '../../database/database.dart';
import '../../domain/entities/expense.dart';

class ExpenseModel extends ExpenseEntity {
  const ExpenseModel({
    required super.id,
    required super.amount,
    required super.category,
    super.note,
    required super.date,
    super.localImagePath,
    super.remoteImageUrl,
    super.isSynced,
    required super.createdAt,
  });


  factory ExpenseModel.fromDrift(Expense drift) {
    return ExpenseModel(
      id: drift.id,
      amount: drift.amount,
      category: drift.category,
      note: drift.note,
      date: drift.date,
      localImagePath: drift.localImagePath,
      remoteImageUrl: drift.remoteImageUrl,
      isSynced: drift.isSynced,
      createdAt: drift.createdAt,
    );
  }


  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    return ExpenseModel(
      id: json['id'],
      amount: double.parse(json['amount'].toString()),
      category: json['category'],
      note: json['note'],
      date: DateTime.parse(json['date']),
      remoteImageUrl: json['imageUrl'],
      isSynced: true,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }


  ExpensesCompanion toCompanion() {
    return ExpensesCompanion(
      id: Value(id),
      amount: Value(amount),
      category: Value(category),
      note: note != null ? Value(note!) : const Value.absent(),
      date: Value(date),
      localImagePath:
          localImagePath != null ? Value(localImagePath!) : const Value.absent(),
      remoteImageUrl:
          remoteImageUrl != null ? Value(remoteImageUrl!) : const Value.absent(),
      isSynced: Value(isSynced),
      createdAt: Value(createdAt),
    );
  }
}
