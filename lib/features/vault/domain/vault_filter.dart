enum VaultSort {
  newest('Newest', 'invoice_date', ascending: false),
  oldest('Oldest', 'invoice_date', ascending: true),
  highestAmount('Highest amount', 'total_amount', ascending: false),
  lowestAmount('Lowest amount', 'total_amount', ascending: true);

  const VaultSort(this.label, this.column, {required this.ascending});

  final String label;
  final String column;
  final bool ascending;
}
