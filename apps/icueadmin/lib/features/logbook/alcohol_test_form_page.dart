import 'package:core_ui/core_ui.dart';
import 'package:drivers/drivers.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/analytics/app_events.dart';
import 'package:logbook/logbook.dart';
import 'package:provider/provider.dart';

class AlcoholTestFormPage extends StatefulWidget {
  const AlcoholTestFormPage({super.key});

  @override
  State<AlcoholTestFormPage> createState() => _AlcoholTestFormPageState();
}

class _AlcoholTestFormPageState extends State<AlcoholTestFormPage> {
  final _formKey = GlobalKey<FormState>();

  Driver? _selectedDriver;
  String _status = 'PASSED';
  final TextEditingController _readingController = TextEditingController(
    text: '0.00',
  );

  String? _photoName;
  List<int>? _photoBytes;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DriverProvider>().fetchDrivers();
    });
  }

  @override
  void dispose() {
    _readingController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_selectedDriver == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a driver')));
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final readingVal = double.tryParse(_readingController.text.trim()) ?? 0.0;
    final driverName =
        '${_selectedDriver!.firstName} ${_selectedDriver!.lastName ?? ''}'
            .trim();
    final driverMobile = _selectedDriver!.mobile?.toString() ?? '';

    final req = AlcoholTestSubmissionRequest(
      personId: _selectedDriver!.id,
      personName: driverName,
      personMobile: driverMobile,
      reading: readingVal,
      status: _status,
      fileName: _photoName,
      fileBytes: _photoBytes,
    );

    final success = await context.read<LogBookProvider>().submitAlcoholTest(
      req,
    );

    if (!mounted) return;

    if (success) {
      track(AppEvents.alcoholTestSubmitted);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alcohol test recorded successfully!')),
      );
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<LogBookProvider>().errorMessage ??
                'Failed to submit alcohol test.',
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final driverProvider = context.watch<DriverProvider>();
    final logBookProvider = context.watch<LogBookProvider>();
    final drivers = driverProvider.drivers;

    return Scaffold(
      appBar: AppBar(title: const Text('Driver Breathalyzer Test')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.indigo.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.security_rounded, color: Colors.indigo.shade800),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Record mandatory daily pre-trip breathalyzer tests for active drivers.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.indigo.shade900,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppSearchableAutocomplete<Driver>(
              label: 'Driver *',
              hintText: 'Search driver by name or mobile...',
              optionsBuilder: (textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return drivers;
                }
                final query = textEditingValue.text.toLowerCase();
                return drivers.where(
                  (d) => '${d.firstName} ${d.lastName ?? ''} ${d.mobile ?? ''}'
                      .toLowerCase()
                      .contains(query),
                );
              },
              displayStringForOption: (d) =>
                  '${d.firstName} ${d.lastName ?? ''} (${d.mobile ?? ''})'
                      .trim(),
              initialSelection: _selectedDriver,
              onSelected: (d) => setState(() => _selectedDriver = d),
              validator: (_) => _selectedDriver == null
                  ? 'Driver selection is required'
                  : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(
                labelText: 'Test Result *',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'PASSED',
                  child: Text('PASSED (0.00 % BAC)'),
                ),
                DropdownMenuItem(
                  value: 'FAILED',
                  child: Text('FAILED (Positive BAC)'),
                ),
              ],
              onChanged: (val) {
                setState(() {
                  _status = val ?? 'PASSED';
                  if (_status == 'PASSED') {
                    _readingController.text = '0.00';
                  }
                });
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _readingController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'BAC Meter Reading (% BAC) *',
                border: OutlineInputBorder(),
                suffixText: '% BAC',
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Required';
                if (double.tryParse(val.trim()) == null) {
                  return 'Enter a valid decimal number';
                }
                return null;
              },
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
                    _photoName != null
                        ? Icons.camera_alt_rounded
                        : Icons.photo_camera_outlined,
                    color: _photoName != null ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _photoName ?? 'Breathalyzer device screen photo',
                      style: TextStyle(
                        fontSize: 13,
                        color: _photoName != null
                            ? Colors.black
                            : Colors.grey.shade600,
                      ),
                    ),
                  ),
                  if (_photoName != null)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        setState(() {
                          _photoName = null;
                          _photoBytes = null;
                        });
                      },
                    )
                  else
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _photoName = 'breathalyzer_test.jpg';
                          _photoBytes = [1, 2, 3, 4];
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
              onPressed: logBookProvider.isLoading ? null : _submit,
              icon: const Icon(Icons.verified_user_rounded),
              label: logBookProvider.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Submit Alcohol Test Record',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
