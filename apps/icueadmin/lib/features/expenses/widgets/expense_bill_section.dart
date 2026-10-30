import 'package:flutter/material.dart';

class ExpenseBillSection extends StatelessWidget {
  const ExpenseBillSection({
    super.key,
    required this.billDate,
    required this.onSelectBillDate,
    required this.billNoController,
    required this.billAmountController,
    required this.vendorNameController,
    required this.status,
    required this.onStatusChanged,
    required this.billFileName,
    required this.onPickBillFile,
    required this.onRemoveBillFile,
  });

  final DateTime billDate;
  final VoidCallback onSelectBillDate;
  final TextEditingController billNoController;
  final TextEditingController billAmountController;
  final TextEditingController vendorNameController;
  final String status;
  final ValueChanged<String?> onStatusChanged;
  final String? billFileName;
  final VoidCallback onPickBillFile;
  final VoidCallback onRemoveBillFile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr =
        '${billDate.day.toString().padLeft(2, '0')}/${billDate.month.toString().padLeft(2, '0')}/${billDate.year}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bill & Invoice Details',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: onSelectBillDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Bill Date *',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today_rounded, size: 18),
                  ),
                  child: Text(dateStr, style: const TextStyle(fontSize: 14)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: status,
                decoration: const InputDecoration(
                  labelText: 'Bill Status *',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'UnBilled', child: Text('UnBilled')),
                  DropdownMenuItem(value: 'Billed', child: Text('Billed')),
                  DropdownMenuItem(value: 'Paid', child: Text('Paid')),
                ],
                onChanged: onStatusChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: billNoController,
          decoration: const InputDecoration(
            labelText: 'Bill / Invoice No',
            hintText: 'Leave empty to auto-generate',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: billAmountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Bill Amount (₹) *',
                  border: OutlineInputBorder(),
                  prefixText: '₹ ',
                ),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Required' : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: vendorNameController,
                decoration: const InputDecoration(
                  labelText: 'Vendor / Merchant Name',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              Icon(
                billFileName != null
                    ? Icons.receipt_long_rounded
                    : Icons.upload_file_rounded,
                color: billFileName != null ? Colors.green : Colors.grey,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  billFileName ?? 'No invoice photo uploaded',
                  style: TextStyle(
                    fontSize: 13,
                    color: billFileName != null
                        ? Colors.black
                        : Colors.grey.shade600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (billFileName != null)
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: onRemoveBillFile,
                  tooltip: 'Remove File',
                )
              else
                TextButton.icon(
                  onPressed: onPickBillFile,
                  icon: const Icon(Icons.attach_file, size: 16),
                  label: const Text('Attach'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
