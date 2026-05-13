import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/expense_provider.dart';

class SummaryBar extends ConsumerWidget {
  const SummaryBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // only rebuilds when summary changes, not when expenses change
    final summary = ref.watch(
      expenseProvider.select((s) => s.summary),
    );
    final formatter = NumberFormat.compact();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _summaryItem(context, 'Today', summary.today, formatter),
          _divider(),
          _summaryItem(context, 'This Week', summary.week, formatter),
          _divider(),
          _summaryItem(context, 'This Month', summary.month, formatter),
        ],
      ),
    );
  }

  Widget _summaryItem(BuildContext context, String label, double amount,
      NumberFormat formatter) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 4),
        Text(
          '\u20B9${formatter.format(amount)}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 30,
      color: Colors.grey[300],
    );
  }
}
