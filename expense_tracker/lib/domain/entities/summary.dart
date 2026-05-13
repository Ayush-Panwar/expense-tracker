class SummaryEntity {
  final double today;
  final double week;
  final double month;

  const SummaryEntity({
    this.today = 0,
    this.week = 0,
    this.month = 0,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SummaryEntity &&
          today == other.today &&
          week == other.week &&
          month == other.month;

  @override
  int get hashCode => today.hashCode ^ week.hashCode ^ month.hashCode;
}
