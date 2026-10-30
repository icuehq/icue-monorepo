import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/routing/app_routes.dart';
import 'package:logbook/logbook.dart';
import 'package:provider/provider.dart';

class ComplaintsDashboardPage extends StatefulWidget {
  const ComplaintsDashboardPage({super.key});

  @override
  State<ComplaintsDashboardPage> createState() =>
      _ComplaintsDashboardPageState();
}

class _ComplaintsDashboardPageState extends State<ComplaintsDashboardPage> {
  String _countBy = 'Status';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LogBookProvider>().fetchComplaintsStats(countBy: _countBy);
      context.read<LogBookProvider>().fetchComplaintCategories();
    });
  }

  void _onCountByChanged(String? val) {
    if (val == null || val == _countBy) return;
    setState(() => _countBy = val);
    context.read<LogBookProvider>().fetchComplaintsStats(countBy: val);
  }

  void _navigateToFilteredComplaints(ComplaintDashboardItem item) {
    if (_countBy == 'Status') {
      context.push(
        AppRoutes.complaints,
        extra: {'status': item.status},
      );
    } else if (_countBy == 'Category') {
      context.push(
        AppRoutes.complaints,
        extra: {'categoryId': item.categoryId},
      );
    } else {
      context.push(
        AppRoutes.complaints,
        extra: {'vehicleId': item.vehicleId},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LogBookProvider>();
    final stats = provider.stats;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Complaints Overview'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt_rounded),
            tooltip: 'All Complaints',
            onPressed: () => context.push(AppRoutes.complaints),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: DropdownButtonFormField<String>(
              initialValue: _countBy,
              decoration: InputDecoration(
                labelText: 'Group Complaints By',
                filled: true,
                fillColor: Theme.of(context).cardColor,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              items: const [
                DropdownMenuItem(value: 'Status', child: Text('Status')),
                DropdownMenuItem(value: 'Category', child: Text('Category')),
                DropdownMenuItem(value: 'Vehicle', child: Text('Vehicle')),
              ],
              onChanged: _onCountByChanged,
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.addComplaint),
        icon: const Icon(Icons.add),
        label: const Text('New Complaint'),
      ),
      body: provider.isLoading && stats.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => context
                  .read<LogBookProvider>()
                  .fetchComplaintsStats(countBy: _countBy),
              child: stats.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 120),
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle_outline_rounded,
                                size: 64,
                                color: Colors.green.shade300,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No complaints recorded!',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      itemCount: stats.length,
                      itemBuilder: (context, index) {
                        final item = stats[index];
                        final title = item.status ??
                            item.category ??
                            item.vehicle ??
                            'Unknown';

                        return Card(
                          elevation: 1,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _navigateToFilteredComplaints(item),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          title,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '${item.totalCount} complaints',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue.shade800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (item.statuses.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: item.statuses.map((s) {
                                        return Chip(
                                          visualDensity: VisualDensity.compact,
                                          label: Text(
                                            '${s.status}: ${s.count}',
                                            style: const TextStyle(fontSize: 11),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
