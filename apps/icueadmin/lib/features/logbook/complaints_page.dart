import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/features/logbook/widgets/complaint_card.dart';
import 'package:icueadmin/routing/app_routes.dart';
import 'package:logbook/logbook.dart';
import 'package:provider/provider.dart';

class ComplaintsPage extends StatefulWidget {
  const ComplaintsPage({
    super.key,
    this.status,
    this.categoryId,
    this.vehicleId,
  });

  final String? status;
  final int? categoryId;
  final int? vehicleId;

  @override
  State<ComplaintsPage> createState() => _ComplaintsPageState();
}

class _ComplaintsPageState extends State<ComplaintsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedStatus;
  int? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.status;
    _selectedCategoryId = widget.categoryId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LogBookProvider>().fetchComplaints(
        status: _selectedStatus,
        categoryId: _selectedCategoryId,
        vehicleId: widget.vehicleId,
      );
      context.read<LogBookProvider>().fetchComplaintCategories();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onFilterChanged() {
    context.read<LogBookProvider>().fetchComplaints(
      status: _selectedStatus,
      categoryId: _selectedCategoryId,
      vehicleId: widget.vehicleId,
      complaintNo: _searchQuery.isNotEmpty ? _searchQuery : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LogBookProvider>();
    final complaints = provider.complaints;
    final categories = provider.categories;

    final filtered = complaints.where((c) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return c.complaintNo.toString().contains(q) ||
          c.vehicleNo.toLowerCase().contains(q) ||
          c.categoryName.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Complaints'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              _onFilterChanged();
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(68),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by complaint #, vehicle, or issue...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Theme.of(context).cardColor,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.addComplaint),
        icon: const Icon(Icons.add),
        label: const Text('New Complaint'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChip(
                    label: Text(_selectedStatus ?? 'All Statuses'),
                    selected: _selectedStatus != null,
                    onSelected: (_) {
                      showModalBottomSheet<void>(
                        context: context,
                        builder: (ctx) => ListView(
                          shrinkWrap: true,
                          padding: const EdgeInsets.all(16),
                          children: [
                            const Text(
                              'Filter by Status',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 10),
                            ListTile(
                              title: const Text('All Statuses'),
                              onTap: () {
                                Navigator.pop(ctx);
                                setState(() => _selectedStatus = null);
                                _onFilterChanged();
                              },
                            ),
                            ...[
                              'Open',
                              'In-Progress',
                              'Resolved',
                              'Closed',
                            ].map(
                              (s) => ListTile(
                                title: Text(s),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  setState(() => _selectedStatus = s);
                                  _onFilterChanged();
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: Text(
                      _selectedCategoryId != null
                          ? categories
                                .firstWhere(
                                  (c) => c.id == _selectedCategoryId,
                                  orElse: () => const ComplaintCategory(
                                    id: 0,
                                    name: 'Category',
                                  ),
                                )
                                .name
                          : 'All Categories',
                    ),
                    selected: _selectedCategoryId != null,
                    onSelected: (_) {
                      showModalBottomSheet<void>(
                        context: context,
                        builder: (ctx) => ListView(
                          shrinkWrap: true,
                          padding: const EdgeInsets.all(16),
                          children: [
                            const Text(
                              'Filter by Category',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 10),
                            ListTile(
                              title: const Text('All Categories'),
                              onTap: () {
                                Navigator.pop(ctx);
                                setState(() => _selectedCategoryId = null);
                                _onFilterChanged();
                              },
                            ),
                            ...categories.map(
                              (c) => ListTile(
                                title: Text(c.name),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  setState(() => _selectedCategoryId = c.id);
                                  _onFilterChanged();
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  if (_selectedStatus != null ||
                      _selectedCategoryId != null) ...[
                    const SizedBox(width: 8),
                    ActionChip(
                      avatar: const Icon(Icons.clear, size: 14),
                      label: const Text('Clear Filters'),
                      onPressed: () {
                        setState(() {
                          _selectedStatus = null;
                          _selectedCategoryId = null;
                        });
                        _onFilterChanged();
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: provider.isLoading && complaints.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () async {
                      _onFilterChanged();
                    },
                    child: filtered.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              const SizedBox(height: 100),
                              Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.task_alt_rounded,
                                      size: 56,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      _searchQuery.isNotEmpty
                                          ? 'No complaints match "$_searchQuery"'
                                          : 'No complaints found for current filter.',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.only(top: 6, bottom: 80),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final complaint = filtered[index];
                              return ComplaintCard(
                                complaint: complaint,
                                onTap: () {
                                  context.push(
                                    AppRoutes.complaintDetails,
                                    extra: complaint,
                                  );
                                },
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
