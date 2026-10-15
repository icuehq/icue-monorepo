import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/marks_correction.dart';
import '../../providers/exam_provider.dart';
import '../../utils/app_utils.dart';
import '../../widgets/no_data_widget.dart';

enum CorrectionFilterStatus { pending, approved, rejected }

class MarksCorrectionRequestsPage extends StatefulWidget {
  const MarksCorrectionRequestsPage({super.key});

  @override
  State<MarksCorrectionRequestsPage> createState() =>
      _MarksCorrectionRequestsPageState();
}

class _MarksCorrectionRequestsPageState
    extends State<MarksCorrectionRequestsPage> {
  CorrectionFilterStatus _selectedFilter = CorrectionFilterStatus.pending;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRequests();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRequests() async {
    final provider = context.read<ExamProvider>();
    String? statusParam;
    switch (_selectedFilter) {
      case CorrectionFilterStatus.pending:
        statusParam = 'Pending';
        break;
      case CorrectionFilterStatus.approved:
        statusParam = 'Approved';
        break;
      case CorrectionFilterStatus.rejected:
        statusParam = 'Rejected';
        break;
    }
    await provider.getMarksCorrectionRequests(correctionStatus: statusParam);
  }

  void _onFilterChanged(CorrectionFilterStatus status) {
    if (_selectedFilter != status) {
      setState(() {
        _selectedFilter = status;
      });
      _loadRequests();
    }
  }

  List<MarksCorrectionItem> _filterItems(List<MarksCorrectionItem> items) {
    if (_searchQuery.trim().isEmpty) {
      return items;
    }
    final query = _searchQuery.trim().toLowerCase();
    return items.where((item) {
      final name = item.studentName?.toLowerCase() ?? '';
      final roll = item.rollNo?.toLowerCase() ?? '';
      final admission = item.admissionNumber?.toLowerCase() ?? '';
      final standard = item.standard?.toLowerCase() ?? '';
      final section = item.section?.toLowerCase() ?? '';
      final exam = item.examName?.toLowerCase() ?? '';
      final subject = item.subject?.toLowerCase() ?? '';
      final reason = item.correction?.reason?.toLowerCase() ?? '';
      final requester = item.correction?.requestedBy?.toLowerCase() ?? '';

      return name.contains(query) ||
          roll.contains(query) ||
          admission.contains(query) ||
          standard.contains(query) ||
          section.contains(query) ||
          exam.contains(query) ||
          subject.contains(query) ||
          reason.contains(query) ||
          requester.contains(query);
    }).toList();
  }

  Future<void> _handleApprove(MarksCorrectionItem item) async {
    final remarksController = TextEditingController(text: 'Approved');
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF059669),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Approve Request',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to approve the marks correction for ${item.studentName ?? "this student"}?',
                style: const TextStyle(fontSize: 14, color: Color(0xFF334155)),
              ),
              const SizedBox(height: 12),
              _buildScoreChangeSummary(item),
              const SizedBox(height: 16),
              const Text(
                'Approval Remarks (optional)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: remarksController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Enter any remarks or notes...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final examProvider = context.read<ExamProvider>();
      await examProvider.approveMarksCorrection(
        context: context,
        examId: item.examId,
        studentId: item.studentId,
        decision: 'Approved',
        remarks: remarksController.text.trim(),
        showLoading: false,
      );
    }
  }

  Future<void> _handleReject(MarksCorrectionItem item) async {
    final remarksController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.cancel_rounded,
                color: Color(0xFFDC2626),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Reject Request',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to reject the marks correction for ${item.studentName ?? "this student"}?',
                style: const TextStyle(fontSize: 14, color: Color(0xFF334155)),
              ),
              const SizedBox(height: 12),
              _buildScoreChangeSummary(item),
              const SizedBox(height: 16),
              const Text(
                'Rejection Reason / Remarks',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: remarksController,
                maxLines: 2,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a rejection reason';
                  }
                  return null;
                },
                decoration: InputDecoration(
                  hintText:
                      'e.g. Marks verified with answer sheet, no error found',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(ctx).pop(true);
              }
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final examProvider = context.read<ExamProvider>();
      await examProvider.approveMarksCorrection(
        context: context,
        examId: item.examId,
        studentId: item.studentId,
        decision: 'Rejected',
        remarks: remarksController.text.trim(),
        showLoading: false,
      );
    }
  }

  Widget _buildScoreChangeSummary(MarksCorrectionItem item) {
    final currentDisplay = item.currentStatus == 'ABSENT'
        ? 'ABSENT'
        : item.currentStatus == 'NA'
        ? 'NA'
        : '${item.currentMarks ?? 0}';

    final reqMarks = item.correction?.marks;
    final reqStatus = item.correction?.markStatus;
    final requestedDisplay = reqStatus == 'ABSENT'
        ? 'ABSENT'
        : reqStatus == 'NA'
        ? 'NA'
        : '${reqMarks ?? 0}';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            children: [
              const Text(
                'Current',
                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 2),
              Text(
                currentDisplay,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF334155),
                ),
              ),
            ],
          ),
          const Icon(
            Icons.arrow_forward_rounded,
            size: 18,
            color: Color(0xFF94A3B8),
          ),
          Column(
            children: [
              const Text(
                'Requested',
                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 2),
              Text(
                requestedDisplay,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2563EB),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('Marks Correction Requests')),
      body: Column(
        children: [
          // Filter Chips and Search Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              children: [
                // Status Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip(
                        label: 'Pending',
                        filter: CorrectionFilterStatus.pending,
                        color: const Color(0xFFF59E0B),
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: 'Approved',
                        filter: CorrectionFilterStatus.approved,
                        color: const Color(0xFF10B981),
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: 'Rejected',
                        filter: CorrectionFilterStatus.rejected,
                        color: const Color(0xFFEF4444),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // Search Input
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by student, roll no, exam, or subject...',
                    hintStyle: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 13,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: Color(0xFF94A3B8),
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            color: const Color(0xFF64748B),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: Color(0xFF096252),
                        width: 1.5,
                      ),
                    ),
                  ),
                  onChanged: (val) {
                    setState(() => _searchQuery = val);
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Content List
          Expanded(
            child: Consumer<ExamProvider>(
              builder: (context, provider, _) {
                if (provider.loadingMarksCorrections) {
                  return const Center(
                    child: CircularProgressIndicator.adaptive(),
                  );
                }

                final filteredList = _filterItems(
                  provider.marksCorrectionRequests,
                );

                if (filteredList.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: _loadRequests,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.45,
                          child: NoDataWidget(
                            size: 200,
                            msg: _searchQuery.isNotEmpty
                                ? 'No requests match "$_searchQuery"'
                                : 'No ${_selectedFilter.name} marks correction requests found.',
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _loadRequests,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    itemCount: filteredList.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = filteredList[index];
                      return _MarksCorrectionCard(
                        item: item,
                        onApprove: () => _handleApprove(item),
                        onReject: () => _handleReject(item),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required CorrectionFilterStatus filter,
    required Color color,
  }) {
    final isSelected = _selectedFilter == filter;

    return ChoiceChip(
      showCheckmark: false,
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => _onFilterChanged(filter),
      selectedColor: color.withValues(alpha: 0.15),
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? color : const Color(0xFF64748B),
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 13,
      ),
      side: BorderSide(
        color: isSelected ? color : const Color(0xFFCBD5E1),
        width: isSelected ? 1.5 : 1,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}

class _MarksCorrectionCard extends StatelessWidget {
  const _MarksCorrectionCard({
    required this.item,
    required this.onApprove,
    required this.onReject,
  });

  final MarksCorrectionItem item;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final status = item.correction?.status ?? item.currentStatus ?? 'Pending';
    final isPending = status.toLowerCase() == 'pending';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Student Name, Avatar & Status Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(
                      0xFF096252,
                    ).withValues(alpha: 0.1),
                    child: Text(
                      (item.studentName != null && item.studentName!.isNotEmpty)
                          ? item.studentName![0].toUpperCase()
                          : 'S',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF096252),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.studentName ?? 'Unknown Student',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (item.standard != null &&
                                item.standard!.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2.5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${item.standard}${item.section != null && item.section!.isNotEmpty ? ' - ${item.section}' : ''}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                              ),
                            ],
                            if (item.rollNo != null &&
                                item.rollNo!.isNotEmpty) ...[
                              Text(
                                'Roll: ${item.rollNo}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                            if (item.admissionNumber != null &&
                                item.admissionNumber!.isNotEmpty &&
                                item.admissionNumber != item.rollNo) ...[
                              Text(
                                'Adm: ${item.admissionNumber}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildStatusBadge(status),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 10),

              // Exam Name & Subject
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.assignment_outlined,
                      size: 16,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${item.examName ?? "Exam"} • ${item.subject ?? "Subject"}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  if (item.maximumMarks != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        'Max: ${item.maximumMarks}${item.passingMarks != null ? ' | Pass: ${item.passingMarks}' : ''}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 12),

              // Visual Score Comparison Box
              _buildScoreDiffWidget(),

              // Reason section
              if (item.correction?.reason != null &&
                  item.correction!.reason!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.format_quote_rounded,
                            size: 15,
                            color: Color(0xFF94A3B8),
                          ),
                          SizedBox(width: 5),
                          Text(
                            'Reason for correction',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.correction!.reason!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF334155),
                          fontStyle: FontStyle.italic,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Requester and Timestamp
              if (item.correction?.requestedBy != null ||
                  item.correction?.requestedDate != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.person_outline_rounded,
                      size: 14,
                      color: Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Requested by: ${item.correction?.requestedBy ?? "Teacher"}${item.correction?.requestedDate != null ? ' • ${item.correction!.requestedDate.formattedFullDateTime()}' : ''}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              // Audit history expandable tile if available
              if (item.history.isNotEmpty) ...[
                const SizedBox(height: 6),
                Theme(
                  data: ThemeData(dividerColor: Colors.transparent),
                  child: Material(
                    type: MaterialType.transparency,
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: const EdgeInsets.only(bottom: 6),
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      title: Text(
                        'Audit History (${item.history.length})',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4F46E5),
                        ),
                      ),
                      children: item.history.map((h) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Marks: ${h.correctionMarks ?? h.oldMarks ?? "-"} (${h.correctionMarkStatus ?? h.oldStatus ?? "-"})',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (h.remarks != null &&
                                        h.remarks!.isNotEmpty)
                                      Text(
                                        'Remarks: ${h.remarks}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Text(
                                '${h.approvedBy ?? h.requestedBy ?? ""} • ${(h.approvedDate ?? h.requestedDate).formattedDate()}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],

              // Action Buttons for Pending items - Neatly aligned side-by-side
              if (isPending) ...[
                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFDC2626),
                          backgroundColor: const Color(0xFFFEF2F2),
                          side: const BorderSide(color: Color(0xFFFECACA)),
                          minimumSize: const Size(0, 42),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.close_rounded, size: 18),
                        label: const Text(
                          'Reject',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: onReject,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 42),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text(
                          'Approve',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: onApprove,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color text;
    Color border;

    switch (status.toLowerCase()) {
      case 'approved':
        bg = const Color(0xFFECFDF5);
        text = const Color(0xFF059669);
        border = const Color(0xFFA7F3D0);
        break;
      case 'rejected':
        bg = const Color(0xFFFEF2F2);
        text = const Color(0xFFDC2626);
        border = const Color(0xFFFECACA);
        break;
      default:
        bg = const Color(0xFFFFFBEB);
        text = const Color(0xFFD97706);
        border = const Color(0xFFFDE68A);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: text, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: text,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreDiffWidget() {
    final curMarks = item.currentMarks;
    final curStatus = item.currentStatus ?? 'PRESENT';
    final curDisplay = (curStatus == 'ABSENT' || curStatus == 'NA')
        ? curStatus
        : '${curMarks ?? 0}';

    final reqMarks = item.correction?.marks;
    final reqStatus = item.correction?.markStatus ?? 'PRESENT';
    final reqDisplay = (reqStatus == 'ABSENT' || reqStatus == 'NA')
        ? reqStatus
        : '${reqMarks ?? 0}';

    String? deltaText;
    Color deltaBg = const Color(0xFFECFDF5);
    Color deltaTextCol = const Color(0xFF059669);
    IconData deltaIcon = Icons.arrow_forward_rounded;

    if (curMarks != null && reqMarks != null) {
      final diff = reqMarks - curMarks;
      if (diff > 0) {
        deltaText = '+$diff';
        deltaBg = const Color(0xFFECFDF5);
        deltaTextCol = const Color(0xFF059669);
        deltaIcon = Icons.trending_up_rounded;
      } else if (diff < 0) {
        deltaText = '$diff';
        deltaBg = const Color(0xFFFEF2F2);
        deltaTextCol = const Color(0xFFDC2626);
        deltaIcon = Icons.trending_down_rounded;
      } else {
        deltaText = 'Status update';
        deltaBg = const Color(0xFFEEF2FF);
        deltaTextCol = const Color(0xFF4F46E5);
        deltaIcon = Icons.swap_horiz_rounded;
      }
    } else if (curStatus != reqStatus) {
      deltaText = reqStatus;
      deltaBg = const Color(0xFFEEF2FF);
      deltaTextCol = const Color(0xFF4F46E5);
      deltaIcon = Icons.swap_horiz_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          // Current score
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CURRENT',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  curDisplay,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: curStatus == 'ABSENT'
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),

          // Center delta pill
          if (deltaText != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: deltaBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: deltaTextCol.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(deltaIcon, size: 14, color: deltaTextCol),
                  const SizedBox(width: 4),
                  Text(
                    deltaText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: deltaTextCol,
                    ),
                  ),
                ],
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Icon(
                Icons.arrow_forward_rounded,
                size: 16,
                color: Color(0xFF94A3B8),
              ),
            ),

          // Requested score
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'REQUESTED',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  reqDisplay,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: reqStatus == 'ABSENT'
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF2563EB),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
