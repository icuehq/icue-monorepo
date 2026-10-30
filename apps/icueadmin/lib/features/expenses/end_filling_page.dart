import 'package:expenses/expenses.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class EndFillingPage extends StatefulWidget {
  const EndFillingPage({
    super.key,
    this.initialFuelType = 'Diesel',
  });

  final String initialFuelType;

  @override
  State<EndFillingPage> createState() => _EndFillingPageState();
}

class _EndFillingPageState extends State<EndFillingPage> {
  final _formKey = GlobalKey<FormState>();
  late String _fuelType;
  final TextEditingController _endReadingController = TextEditingController();

  String? _gaugeFileName;
  List<int>? _gaugeFileBytes;

  @override
  void initState() {
    super.initState();
    _fuelType = widget.initialFuelType;
  }

  @override
  void dispose() {
    _endReadingController.dispose();
    super.dispose();
  }

  Future<void> _submit(String? startReading) async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final req = SelfFillingStatusRequest(
      fuelType: _fuelType,
      gaugeMode: 'end',
      startReading: startReading,
      endReading: _endReadingController.text.trim(),
      gaugeFileName: _gaugeFileName,
      gaugeFileBytes: _gaugeFileBytes,
    );

    final success =
        await context.read<ExpenseProvider>().updateSelfFillingStatus(req);

    if (!mounted) return;

    if (success) {
      context.read<ExpenseProvider>().reset();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Self-filling session completed and closed!'),
        ),
      );
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<ExpenseProvider>().errorMessage ??
                'Failed to record end gauge reading.',
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();
    final startReading = provider.startGaugeReading;
    final filledVehicles = provider.filledVehicleNumbers;

    final startVal = double.tryParse(startReading ?? '0') ?? 0;
    final endVal = double.tryParse(_endReadingController.text.trim()) ?? 0;
    final totalLitres = endVal > startVal ? (endVal - startVal) : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('End Campus Self-Filling'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.deepOrange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.deepOrange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.deepOrange.shade800),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Record the final fuel dispenser meter reading to calculate total volume dispensed.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.deepOrange.shade900,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(Icons.speed_rounded, color: Colors.blue),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Initial Meter Reading',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        Text(
                          startReading != null ? '$startReading L' : 'Not recorded',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _endReadingController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Final Gauge Reading (Litres) *',
                border: OutlineInputBorder(),
                suffixText: 'L',
              ),
              onChanged: (_) => setState(() {}),
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Required';
                final parsed = double.tryParse(val.trim());
                if (parsed == null) return 'Enter a valid number';
                if (startReading != null && parsed < startVal) {
                  return 'Must be >= initial reading ($startVal L)';
                }
                return null;
              },
            ),
            if (totalLitres > 0) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Dispensed Volume:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${totalLitres.toStringAsFixed(2)} Litres',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (filledVehicles.isNotEmpty) ...[
              Text(
                'Vehicles Refueled (${filledVehicles.length})',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: filledVehicles.map((v) {
                  return Chip(
                    avatar: const Icon(Icons.check_circle,
                        size: 16, color: Colors.green),
                    label: Text(v),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
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
                    _gaugeFileName != null
                        ? Icons.camera_alt_rounded
                        : Icons.photo_camera_outlined,
                    color: _gaugeFileName != null ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _gaugeFileName ?? 'Final pump gauge meter photo',
                      style: TextStyle(
                        fontSize: 13,
                        color: _gaugeFileName != null
                            ? Colors.black
                            : Colors.grey.shade600,
                      ),
                    ),
                  ),
                  if (_gaugeFileName != null)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        setState(() {
                          _gaugeFileName = null;
                          _gaugeFileBytes = null;
                        });
                      },
                    )
                  else
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _gaugeFileName = 'gauge_meter_end.jpg';
                          _gaugeFileBytes = [5, 6, 7, 8];
                        });
                      },
                      icon: const Icon(Icons.camera_alt, size: 16),
                      label: const Text('Capture'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: provider.isLoading ? null : () => _submit(startReading),
              icon: const Icon(Icons.stop_circle_rounded),
              label: provider.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Finish & Close Session',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
