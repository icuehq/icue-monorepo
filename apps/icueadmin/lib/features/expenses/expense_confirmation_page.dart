import 'package:core_ui/core_ui.dart';
import 'package:expenses/expenses.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/routing/app_routes.dart';

class ExpenseConfirmationPage extends StatelessWidget {
  const ExpenseConfirmationPage({super.key, required this.data});

  final ExpenseConfirmationData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSelfFilling = data.mode == 'SelfFilling';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Recorded'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.green.shade300, width: 2),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.green,
                  size: 42,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Expense Submitted Successfully!',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'The transaction has been recorded and updated in fleet ledgers.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _DetailRow(
                        label: 'Category',
                        value: data.expenseType.expenseTypeDesc,
                      ),
                      if (data.vehicleNumber != null) ...[
                        const Divider(height: 18),
                        _DetailRow(
                          label: 'Vehicle',
                          value: data.vehicleNumber!,
                        ),
                      ],
                      if (data.amount != null) ...[
                        const Divider(height: 18),
                        _DetailRow(
                          label: 'Bill Amount',
                          value:
                              num.tryParse(data.amount!.trim())?.toRupees() ??
                              '-',
                          isHighlighted: true,
                        ),
                      ],
                      if (data.mode != null) ...[
                        const Divider(height: 18),
                        _DetailRow(label: 'Mode', value: data.mode!),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        if (isSelfFilling) {
                          context.pop();
                        } else {
                          context.pushReplacement(AppRoutes.repairsExpense);
                        }
                      },
                      child: const Text('Add Another'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        if (isSelfFilling) {
                          context.pushReplacement(
                            AppRoutes.endFilling,
                            extra: data.fuelType ?? '',
                          );
                        } else {
                          context.go(AppRoutes.dashboard);
                        }
                      },
                      child: Text(isSelfFilling ? 'End Filling' : 'Dashboard'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.isHighlighted = false,
  });

  final String label;
  final String value;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w600,
            color: isHighlighted ? Colors.green.shade700 : Colors.black87,
          ),
        ),
      ],
    );
  }
}
