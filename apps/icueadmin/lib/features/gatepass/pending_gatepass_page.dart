import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:gatepass/gatepass.dart';
import 'package:icueadmin/analytics/app_events.dart';
import 'package:icueadmin/features/gatepass/widgets/gatepass_request_card.dart';
import 'package:icueadmin/features/reports/widgets/report_empty_state.dart';
import 'package:provider/provider.dart';

class PendingGatePassPage extends StatefulWidget {
  const PendingGatePassPage({super.key});

  @override
  State<PendingGatePassPage> createState() => _PendingGatePassPageState();
}

class _PendingGatePassPageState extends State<PendingGatePassPage> {
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchRequests();
    });
  }

  void _fetchRequests() {
    context.read<GatePassProvider>().fetchGatePassRequests(_selectedDate);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _fetchRequests();
    }
  }

  Future<void> _handleStatusUpdate(
    GatePassRequest request,
    String status,
  ) async {
    final isApprove = status == 'APPROVE';
    final provider = context.read<GatePassProvider>();

    final success = await provider.updateGatePassStatus(
      id: request.id,
      personId: request.personId,
      date: request.requestDate,
      status: status,
    );

    if (!mounted) return;

    if (success) {
      track(AppEvents.gatepassReviewed, {'status': status});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gate pass for ${request.name} ${isApprove ? "approved" : "rejected"}.',
          ),
          backgroundColor: isApprove ? Colors.green : Colors.red,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Status update failed.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GatePassProvider>();
    final requests = provider.requests;
    final dateDisplay = AppDateUtils.formatDisplayDate(_selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gate Pass Requests'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchRequests,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Theme.of(context).cardColor,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(
                      'Date: $dateDisplay',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                if (requests.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${requests.length} Pending',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: provider.isLoading && requests.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () async => _fetchRequests(),
                    child: requests.isEmpty
                        ? ReportEmptyState(
                            icon: Icons.assignment_turned_in_outlined,
                            message:
                                'No pending gate pass requests for $dateDisplay.',
                            onRetry: _fetchRequests,
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: requests.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final req = requests[index];
                              return GatePassRequestCard(
                                request: req,
                                onApprove: () =>
                                    _handleStatusUpdate(req, 'APPROVE'),
                                onReject: () =>
                                    _handleStatusUpdate(req, 'REJECT'),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}
