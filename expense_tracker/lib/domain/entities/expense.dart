class ExpenseEntity {
  final String id;
  final double amount;
  final String category;
  final String? note;
  final DateTime date;
  final String? localImagePath;
  final String? remoteImageUrl;
  final bool isSynced;
  final DateTime createdAt;

  const ExpenseEntity({
    required this.id,
    required this.amount,
    required this.category,
    this.note,
    required this.date,
    this.localImagePath,
    this.remoteImageUrl,
    this.isSynced = false,
    required this.createdAt,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExpenseEntity &&
          id == other.id &&
          amount == other.amount &&
          category == other.category &&
          note == other.note &&
          isSynced == other.isSynced &&
          remoteImageUrl == other.remoteImageUrl;

  @override
  int get hashCode => id.hashCode;
}
