import 'package:expenses/expenses.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class SelfFillingPage extends StatefulWidget {
  const SelfFillingPage({
    super.key,
    this.initialFuelType = 'Diesel',
  });

  final String initialFuelType;

  @override
  State<SelfFillingPage> createState() => _SelfFillingPageState();
}

class _SelfFillingPageState extends State<SelfFillingPage> {
  final _formKey = GlobalKey<FormState>();
  late String _fuelType;
  final TextEditingController _startReadingController =
      TextEditingController();

  String? _gaugeFileName;
  List<int>? _gaugeFileBytes;

  @override
  void initState() {
    super.initState();
    _fuelType = widget.initialFuelType;
    final existing = context.read<ExpenseProvider>().startGaugeReading;
    if (existing != null) {
      _startReadingController.text = existing;
    }
  }

  @override
  void dispose() {
    _startReadingController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final req = SelfFillingStatusRequest(
      fuelType: _fuelType,
      gaugeMode: 'start',
      startReading: _startReadingController.text.trim(),
      gaugeFileName: _gaugeFileName,
      gaugeFileBytes: _gaugeFileBytes,
    );

    final success =
        await context.read<ExpenseProvider>().updateSelfFillingStatus(req);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Self-filling session started successfully!'),
        ),
      );
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<ExpenseProvider>().errorMessage ??
                'Failed to record start gauge reading.',
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Start Campus Self-Filling'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.green.shade800),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Record the initial fuel dispenser meter reading before refueling vehicles.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.green.shade900,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _fuelType,
              decoration: const InputDecoration(
                labelText: 'Fuel Type *',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'Diesel', child: Text('Diesel')),
                DropdownMenuItem(value: 'Petrol', child: Text('Petrol')),
                DropdownMenuItem(value: 'CNG', child: Text('CNG')),
              ],
              onChanged: (val) => setState(() => _fuelType = val ?? 'Diesel'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _startReadingController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Initial Gauge Reading (Litres) *',
                border: OutlineInputBorder(),
                suffixText: 'L',
              ),
              validator: (val) =>
                  val == null || val.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
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
                      _gaugeFileName ?? 'Initial pump gauge meter photo',
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
                          _gaugeFileName = 'gauge_meter_start.jpg';
                          _gaugeFileBytes = [1, 2, 3, 4];
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
              onPressed: provider.isLoading ? null : _submit,
              icon: const Icon(Icons.play_arrow_rounded),
              label: provider.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Confirm & Start Session',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
