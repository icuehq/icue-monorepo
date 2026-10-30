import 'package:flutter/material.dart';
import 'package:icueadmin/features/logbook/widgets/complaint_status_badge.dart';
import 'package:icueadmin/features/logbook/widgets/update_complaint_modal.dart';
import 'package:logbook/logbook.dart';
import 'package:provider/provider.dart';

class ComplaintDetailsPage extends StatefulWidget {
  const ComplaintDetailsPage({super.key, required this.complaint});

  final Complaint complaint;

  @override
  State<ComplaintDetailsPage> createState() => _ComplaintDetailsPageState();
}

class _ComplaintDetailsPageState extends State<ComplaintDetailsPage> {
  late Complaint _complaint;

  @override
  void initState() {
    super.initState();
    _complaint = widget.complaint;
  }

  Future<void> _handleUpdate(UpdateComplaintRequest req) async {
    final success = await context.read<LogBookProvider>().updateComplaint(req);
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complaint updated successfully!')),
      );
      setState(() {
        _complaint = Complaint(
          id: _complaint.id,
          complaintNo: _complaint.complaintNo,
          vehicleNo: _complaint.vehicleNo,
          categoryName: _complaint.categoryName,
          currStatus: req.status,
          currAction: req.action,
          stsUpdatedDt: DateTime.now().toIso8601String().split('T').first,
          stsUpdatedTime:
              '${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
          details: [
            ComplaintDetail(
              status: req.status,
              action: req.action,
              date: DateTime.now().toIso8601String().split('T').first,
              time:
                  '${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
              description: req.description ?? '',
              createdBy: 'Admin',
            ),
            ..._complaint.details,
          ],
        );
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<LogBookProvider>().errorMessage ??
                'Failed to update complaint.',
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Complaint #${_complaint.complaintNo}'),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              UpdateComplaintModal.show(
                context,
                complaint: _complaint,
                onSubmit: _handleUpdate,
              );
            },
            icon: const Icon(Icons.edit_note_rounded),
            label: const Text(
              'Update Status / Log Action',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _complaint.vehicleNo,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      ComplaintStatusBadge(status: _complaint.currStatus),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Category: ${_complaint.categoryName}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  if (_complaint.currAction.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Latest Action: ${_complaint.currAction}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Activity & Resolution History',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (_complaint.details.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No status updates recorded yet.'),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _complaint.details.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final detail = _complaint.details[index];

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ComplaintStatusBadge(status: detail.status),
                          Text(
                            '${detail.date} ${detail.time}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      if (detail.action.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Action: ${detail.action}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                      if (detail.description.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          detail.description,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade800,
                            height: 1.35,
                          ),
                        ),
                      ],
                      if (detail.createdBy.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.person_outline,
                                size: 14, color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Text(
                              detail.createdBy,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
