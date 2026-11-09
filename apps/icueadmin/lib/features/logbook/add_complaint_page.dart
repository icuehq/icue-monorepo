import 'package:auth/auth.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/analytics/app_events.dart';
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

  final List<PickedFile> _photos = [];

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

  Widget _photosSection() {
    final limit =
        context
            .watch<AuthProvider>()
            .appSettings
            ?.vehicle
            ?.complaintImageLimit ??
        1;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Defect / Damage photos (optional, up to $limit)',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          for (var i = 0; i < _photos.length; i++)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.image_rounded, color: Colors.green),
              title: Text(_photos[i].name, overflow: TextOverflow.ellipsis),
              trailing: IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () => setState(() => _photos.removeAt(i)),
              ),
            ),
          if (_photos.length < limit)
            AppButton(
              label: 'Attach',
              onPressed: () async {
                final picked = await pickFile(context);
                if (picked == null || !mounted) return;
                setState(() => _photos.add(picked));
              },
              variant: AppButtonVariant.ghost,
              leadingIcon: Icons.attach_file,
            ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_selectedVehicle == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a vehicle')));
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
      photos: [
        for (final photo in _photos)
          ComplaintPhoto(name: photo.name, bytes: photo.bytes),
      ],
    );

    final success = await context.read<LogBookProvider>().createComplaint(req);

    if (!mounted) return;

    if (success) {
      track(AppEvents.complaintCreated);
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
      appBar: AppBar(title: const Text('New Vehicle Complaint')),
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
                return vehicles.where(
                  (v) => v.number.toLowerCase().contains(
                    textEditingValue.text.toLowerCase(),
                  ),
                );
              },
              displayStringForOption: (v) => v.number,
              initialSelection: _selectedVehicle,
              onSelected: (v) => setState(() => _selectedVehicle = v),
              validator: (_) => _selectedVehicle == null
                  ? 'Vehicle selection is required'
                  : null,
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
                const DropdownMenuItem(
                  value: 0,
                  child: Text('Others (Specify)'),
                ),
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
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Required';
                  final exists = context.read<LogBookProvider>().categories.any(
                    (c) => c.name.toLowerCase() == val.trim().toLowerCase(),
                  );
                  return exists ? 'Category already exists' : null;
                },
              ),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'Issue Description *',
                hintText:
                    'Describe the symptoms, breakdown location, or defects...',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 4,
              validator: (val) =>
                  val == null || val.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            _photosSection(),
            const SizedBox(height: 24),
            AppButton(
              label: 'Submit Complaint',
              onPressed: logBookProvider.isLoading ? null : _submit,
              leadingIcon: Icons.save_rounded,
              isLoading: logBookProvider.isLoading,
            ),
          ],
        ),
      ),
    );
  }
}
