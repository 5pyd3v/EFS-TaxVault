enum PeriodType {
  monthly('month', 'Monthly'),
  quarterly('quarter', 'Quarterly'),
  annual('year', 'Annual');

  const PeriodType(this.sqlValue, this.label);

  /// Matches the `p_period_type` argument of `get_period_summaries`.
  final String sqlValue;
  final String label;

  /// Exclusive end of the period that starts at [start] — used to build a
  /// `[start, end)` date-range filter when a report row is tapped.
  DateTime endOf(DateTime start) {
    return switch (this) {
      PeriodType.monthly => DateTime(start.year, start.month + 1, 1),
      PeriodType.quarterly => DateTime(start.year, start.month + 3, 1),
      PeriodType.annual => DateTime(start.year + 1, start.month, 1),
    };
  }
}
