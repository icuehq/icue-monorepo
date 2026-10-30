import 'package:flutter/material.dart';
import 'package:gatepass/gatepass.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/analytics/app_events.dart';
import 'package:icueadmin/routing/app_routes.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:routes/routes.dart';

class ConfirmGatePassPage extends StatefulWidget {
  const ConfirmGatePassPage({
    required this.student,
    required this.personType,
    super.key,
  });

  final StudentData student;
  final String personType;

  @override
  State<ConfirmGatePassPage> createState() => _ConfirmGatePassPageState();
}

class _ConfirmGatePassPageState extends State<ConfirmGatePassPage> {
  String? _selectedCategory;
  bool _issued = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GatePassProvider>().fetchGatePassTypes();
    });
  }

  Future<void> _handleIssue() async {
    if (_selectedCategory == null) return;

    final provider = context.read<GatePassProvider>();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final request = CreateGatePassRequest(
      personId: widget.student.id,
      name: widget.student.name,
      classId: widget.student.classId,
      className: widget.student.standard,
      section: widget.student.section,
      admissionNumber: widget.student.admissionNumber,
      gatePassDate: today,
      gatePassType: _selectedCategory!,
      personType: widget.personType,
    );

    final success = await provider.issueGatePass(request);
    if (!mounted) return;

    if (success) {
      track(AppEvents.gatepassIssued);
      setState(() => _issued = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Failed to issue gate pass.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GatePassProvider>();
    final types = provider.gatepassTypes;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Issue Gate Pass')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: theme.primaryColor.withValues(
                        alpha: 0.1,
                      ),
                      child: Icon(
                        Icons.person_rounded,
                        color: theme.primaryColor,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.student.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Adm #${widget.student.admissionNumber} • Class ${widget.student.standard} - ${widget.student.section}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Type: ${widget.personType}',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (!_issued) ...[
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Gate Pass Type *',
                  hintText: 'Select purpose / leave type',
                ),
                items: types.map((t) {
                  return DropdownMenuItem(
                    value: t.category,
                    child: Text(t.displayName),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedCategory = val),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _selectedCategory == null || provider.isLoading
                      ? null
                      : _handleIssue,
                  icon: provider.isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: Text(
                    provider.isLoading ? 'Issuing...' : 'Issue Gate Pass',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ] else ...[
              const Spacer(),
              const CircleAvatar(
                radius: 44,
                backgroundColor: Color(0XFFE8F5E9),
                child: Icon(
                  Icons.verified_rounded,
                  color: Color(0XFF2E7D32),
                  size: 52,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Gate Pass Issued Successfully!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0XFF2E7D32),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'A gate pass for ${_selectedCategory ?? ""} has been registered.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => context.pop(),
                      child: const Text('Issue Another'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => context.go(AppRoutes.dashboard),
                      child: const Text('Go Home'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
