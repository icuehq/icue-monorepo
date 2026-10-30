import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logbook/logbook.dart';
import 'package:provider/provider.dart';
import 'package:vehicles/vehicles.dart';

class AddComplaintPage extends StatefulWidget {
  const AddComplaintPage({super.key});

  @override
  State<AddComplaintPage> createState() => _AddComplaintPageState();
}

class _AddComplaintPageState extends State<AddComplaintPage> {
  final _formKey = GlobalKey<FormState>();

  Vehicle? _selectedVehicle;
  int? _selectedCategoryId;
  String _customCategory = '';
  final TextEditingController _descController = TextEditingController();

  String? _photoName;
  List<int>? _photoBytes;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VehicleProvider>().fetchVehicles();
      context.read<LogBookProvider>().fetchComplaintCategories();
    });
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_selectedVehicle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a vehicle')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final req = CreateComplaintRequest(
      vehicleId: _selectedVehicle!.id,
      vehicleNumber: _selectedVehicle!.number,
      categoryId: _selectedCategoryId ?? 0,
      description: _descController.text.trim(),
      newCategoryName: _selectedCategoryId == 0 && _customCategory.isNotEmpty
          ? _customCategory.trim()
          : null,
      photoBytes: _photoBytes,
      photoName: _photoName,
    );

    final success = await context.read<LogBookProvider>().createComplaint(req);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complaint registered successfully!')),
      );
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<LogBookProvider>().errorMessage ??
                'Failed to register complaint.',
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicleProvider = context.watch<VehicleProvider>();
    final logBookProvider = context.watch<LogBookProvider>();
    final vehicles = vehicleProvider.vehicles;
    final categories = logBookProvider.categories;

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Vehicle Complaint'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppSearchableAutocomplete<Vehicle>(
              label: 'Vehicle *',
              hintText: 'Search vehicle by number...',
              optionsBuilder: (textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return vehicles;
                }
                return vehicles.where((v) => v.number
                    .toLowerCase()
                    .contains(textEditingValue.text.toLowerCase()));
              },
              displayStringForOption: (v) => v.number,
              initialSelection: _selectedVehicle,
              onSelected: (v) => setState(() => _selectedVehicle = v),
              validator: (_) =>
                  _selectedVehicle == null ? 'Vehicle selection is required' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _selectedCategoryId,
              decoration: const InputDecoration(
                labelText: 'Complaint Category *',
                border: OutlineInputBorder(),
              ),
              items: [
                ...categories.map(
                  (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                ),
                const DropdownMenuItem(value: 0, child: Text('Others (Specify)')),
              ],
              onChanged: (id) => setState(() => _selectedCategoryId = id),
              validator: (val) =>
                  val == null ? 'Please select a complaint category' : null,
            ),
            if (_selectedCategoryId == 0) ...[
              const SizedBox(height: 14),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Custom Category Name *',
                  border: OutlineInputBorder(),
                ),
                onSaved: (val) => _customCategory = val ?? '',
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Required' : null,
              ),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'Issue Description *',
                hintText: 'Describe the symptoms, breakdown location, or defects...',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 4,
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
                    _photoName != null
                        ? Icons.image_rounded
                        : Icons.add_a_photo_outlined,
                    color: _photoName != null ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _photoName ?? 'Defect / Damage photo (optional)',
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
                          _photoName = 'defect_photo.jpg';
                          _photoBytes = [1, 2, 3];
                        });
                      },
                      icon: const Icon(Icons.attach_file, size: 16),
                      label: const Text('Attach'),
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
              icon: const Icon(Icons.save_rounded),
              label: logBookProvider.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Submit Complaint',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
