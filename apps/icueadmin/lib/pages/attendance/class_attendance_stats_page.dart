import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/assigned_entities.dart';
import '../../models/class_attendance_stats.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/constants.dart';
import '../../widgets/no_data_widget.dart';
import '../../widgets/report_filter_modal.dart';
import 'class_attendance_details_page.dart';

class ClassAttendanceStatsPage extends StatefulWidget {
  const ClassAttendanceStatsPage({super.key});

  @override
  State<ClassAttendanceStatsPage> createState() =>
      _ClassAttendanceStatsPageState();
}

class _ClassAttendanceStatsPageState extends State<ClassAttendanceStatsPage> {
  FilterMode _filterMode = FilterMode.bydate;
  int _page = 1;
  final int _pageSize = 10;
  int? _selectedClassId;
  DateTime _selectedDate = DateTime.now();
  String _selectedMonth = months[DateTime.now().month - 1]['val']!;
  DateTimeRange? _selectedRange;
  String? _selectedSection;
  String _selectedYear = DateTime.now().year.toString();

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      if (authProvider.assignedEntityClasses.isEmpty) {
        authProvider.getAssignedEntities(context, forAttendance: true);
      }
      _loadPage(1);
    });
  }

  void _loadPage(int page) {
    setState(() => _page = page);
    final provider = context.read<AttendanceProvider>();
    provider.getClassAttendanceStats(
      reportMode: _filterMode,
      fromDate: _filterMode == FilterMode.bydate
          ? _selectedDate
          : _selectedRange?.start,
      toDate: _selectedRange?.end,
      month: _selectedMonth,
      year: _selectedYear,
      classId: _selectedClassId,
      section: _selectedSection,
      pageNumber: page,
      pageSize: _pageSize,
    );
  }

  Future<void> _openFilterSheet() async {
    final result = await ReportFilterModal.show(
      context,
      month: _selectedMonth,
      year: _selectedYear,
      range: _selectedRange,
      filterMode: _filterMode,
      date: _selectedDate,
    );
    if (result == null || !mounted) return;

    setState(() {
      _filterMode = result.mode;
      switch (result.mode) {
        case FilterMode.bydate:
          _selectedDate = result.date ?? DateTime.now();
          _selectedRange = null;
          break;
        case FilterMode.bymonth:
          _selectedMonth = result.month ?? _selectedMonth;
          _selectedYear = result.year ?? _selectedYear;
          _selectedRange = null;
          break;
        case FilterMode.byperiod:
          _selectedRange = result.range;
          break;
      }
    });
    _loadPage(1);
  }

  String get _filterSubtitleText {
    switch (_filterMode) {
      case FilterMode.bydate:
        return 'Date: ${DateFormat('dd MMM yyyy').format(_selectedDate)}';
      case FilterMode.bymonth:
        final mName =
            months.firstWhereOrNull(
              (m) => m['val'] == _selectedMonth,
            )?['name'] ??
            _selectedMonth;
        return 'Month: $mName $_selectedYear';
      case FilterMode.byperiod:
        if (_selectedRange == null) return 'By Range';
        final f = DateFormat('dd MMM yyyy');
        return '${f.format(_selectedRange!.start)} – ${f.format(_selectedRange!.end)}';
    }
  }

  int _resolveClassId(
    ClassAttendanceStatItem item,
    List<AssignedEntityClass> assignedClasses,
  ) {
    if (item.classId != null && item.classId! > 0) {
      return item.classId!;
    }
    final match = assignedClasses.firstWhereOrNull(
      (c) =>
          c.standard.trim().toLowerCase() == item.standard.trim().toLowerCase(),
    );
    if (match != null) {
      return match.classId;
    }
    return int.tryParse(item.standard) ?? 0;
  }

  Color _getPercentColor(double percent) {
    if (percent >= 85) return const Color(0xFF10B981);
    if (percent >= 60) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  Widget _buildFilterHeader(
    BuildContext context,
    List<AssignedEntityClass> assignedClasses,
    List<String> availableSections,
    ThemeData theme,
  ) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Active Date Filter Pill
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _openFilterSheet,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.primaryColor.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 16,
                    color: theme.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _filterSubtitleText,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.primaryColor,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_drop_down,
                    size: 20,
                    color: theme.primaryColor,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Standard & Section Dropdowns
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int?>(
                      value: _selectedClassId,
                      isExpanded: true,
                      hint: const Text(
                        'All Classes',
                        style: TextStyle(fontSize: 13),
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          child: Text(
                            'All Classes',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                        ...assignedClasses.map(
                          (c) => DropdownMenuItem<int?>(
                            value: c.classId,
                            child: Text(
                              c.standard,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _selectedClassId = val;
                          _selectedSection = null;
                        });
                        _loadPage(1);
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: _selectedSection,
                      isExpanded: true,
                      hint: const Text(
                        'All Sec',
                        style: TextStyle(fontSize: 13),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          child: Text(
                            'All Sec',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                        ...availableSections.map(
                          (s) => DropdownMenuItem<String?>(
                            value: s,
                            child: Text(
                              'Sec $s',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                      onChanged:
                          availableSections.isEmpty && _selectedClassId != null
                          ? null
                          : (val) {
                              setState(() => _selectedSection = val);
                              _loadPage(1);
                            },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    ClassAttendanceStatItem item,
    int classId,
    ThemeData theme,
  ) {
    final percentColor = _getPercentColor(item.attdPercent);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ClassAttendanceDetailsPage(
              classId: classId,
              standard: item.standard,
              section: item.section,
              reportMode: _filterMode,
              fromDate: _filterMode == FilterMode.bydate
                  ? _selectedDate
                  : _selectedRange?.start,
              toDate: _selectedRange?.end,
              month: _selectedMonth,
              year: _selectedYear,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Class & Section + Percentage Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.school_rounded,
                    color: theme.primaryColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Standard ${item.standard} - Section ${item.section}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (item.period.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Period ${item.period}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            item.date,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: percentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${item.attdPercent.toStringAsFixed(item.attdPercent % 1 == 0 ? 0 : 1)}%',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: percentColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: item.total > 0 ? (item.presentees / item.total) : 0,
                minHeight: 6,
                backgroundColor: const Color(0xFFFEE2E2),
                valueColor: AlwaysStoppedAnimation<Color>(percentColor),
              ),
            ),
            const SizedBox(height: 12),

            // Metric Breakdown & View Link
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _buildMiniBadge(
                      label: 'Total',
                      value: '${item.total}',
                      color: Colors.grey.shade700,
                    ),
                    const SizedBox(width: 8),
                    _buildMiniBadge(
                      label: 'Present',
                      value: '${item.presentees}',
                      color: const Color(0xFF10B981),
                    ),
                    const SizedBox(width: 8),
                    _buildMiniBadge(
                      label: 'Absent',
                      value: '${item.absentees}',
                      color: const Color(0xFFEF4444),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      'View Details',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: theme.primaryColor,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: theme.primaryColor,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniBadge({
    required String label,
    required String value,
    required Color color,
  }) {
    return RichText(
      text: TextSpan(
        text: '$label: ',
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        children: [
          TextSpan(
            text: value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final assignedClasses = context.watch<AuthProvider>().assignedEntityClasses;
    final attendanceProvider = context.watch<AttendanceProvider>();
    final stats = attendanceProvider.attendanceStats;
    final metadata = attendanceProvider.attendanceStatsMetadata;
    final isLoading = attendanceProvider.attendanceStatsLoading;

    // Available sections for the currently selected class
    final currentClass = assignedClasses.firstWhereOrNull(
      (c) => c.classId == _selectedClassId,
    );
    final availableSections = currentClass?.sections ?? <String>[];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('Class Attendance Stats')),
      body: RefreshIndicator(
        onRefresh: () async => _loadPage(1),
        child: Column(
          children: [
            // Top Filter & Search Bar
            _buildFilterHeader(
              context,
              assignedClasses,
              availableSections,
              theme,
            ),

            // Records Count Header
            if (stats.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Class Attendance Records',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    if (metadata != null && metadata.total > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${stats.length} of ${metadata.total} classes',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

            // Content Area
            Expanded(
              child: isLoading && _page == 1
                  ? const Center(child: CircularProgressIndicator())
                  : stats.isEmpty
                  ? const Center(
                      child: NoDataWidget(
                        msg: 'No attendance statistics found for this filter.',
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemCount: stats.length + 1,
                      itemBuilder: (context, index) {
                        if (index < stats.length) {
                          final item = stats[index];
                          final targetClassId = _resolveClassId(
                            item,
                            assignedClasses,
                          );

                          return _buildStatCard(
                            context,
                            item,
                            targetClassId,
                            theme,
                          );
                        }

                        // Load more indicator / button
                        if (isLoading) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        final totalItems = metadata?.total ?? stats.length;
                        if (stats.length < totalItems) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: theme.primaryColor,
                                  side: BorderSide(
                                    color: theme.primaryColor.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  minimumSize: const Size(180, 44),
                                ),
                                onPressed: () => _loadPage(_page + 1),
                                icon: const Icon(Icons.expand_more_rounded),
                                label: Text(
                                  'Load More (${stats.length} of $totalItems)',
                                ),
                              ),
                            ),
                          );
                        }

                        return const SizedBox(height: 16);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
