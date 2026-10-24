import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/class_attendance_detail.dart';
import '../../models/meta_data.dart';
import '../../providers/attendance_provider.dart';
import '../../utils/constants.dart';

class ClassAttendanceDetailsPage extends StatefulWidget {
  const ClassAttendanceDetailsPage({
    super.key,
    required this.classId,
    required this.standard,
    required this.section,
    required this.reportMode,
    this.fromDate,
    this.toDate,
    this.month,
    this.year,
  });

  final int classId;
  final DateTime? fromDate;
  final String? month;
  final FilterMode reportMode;
  final String section;
  final String standard;
  final DateTime? toDate;
  final String? year;

  @override
  State<ClassAttendanceDetailsPage> createState() =>
      _ClassAttendanceDetailsPageState();
}

class _ClassAttendanceDetailsPageState
    extends State<ClassAttendanceDetailsPage> {
  // Cached data per status tab to eliminate reload & layout shift
  final Map<String, List<ClassAttendanceStudentItem>> _cacheByStatus = {};

  bool _isInitialLoading = true;
  bool _isLoadingMore = false;
  final Map<String, bool> _loadingByStatus = {
    '': false,
    'P': false,
    'A': false,
  };

  final Map<String, Metadata?> _metadataByStatus = {};
  final int _pageSize = 10;
  final Map<String, int> _pagesByStatus = {'': 1, 'P': 1, 'A': 1};
  String _selectedStatus = ''; // "" for All, "P" for Present, "A" for Absent
  String? _sessionAttdMode;
  // Persistent session info so the header NEVER disappears or shifts layout
  String? _sessionAttendedBy;

  String? _sessionPeriod;
  String? _sessionTime;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _fetchPage(status: '', page: 1, isInitial: true);
    });
  }

  Future<void> _fetchPage({
    required String status,
    required int page,
    bool isInitial = false,
    bool isLoadingMore = false,
  }) async {
    if (isInitial) {
      setState(() => _isInitialLoading = true);
    } else if (isLoadingMore) {
      setState(() => _isLoadingMore = true);
    } else {
      setState(() => _loadingByStatus[status] = true);
    }

    final result = await context.read<AttendanceProvider>().getClassAttendance(
      reportMode: widget.reportMode,
      classId: widget.classId,
      section: widget.section,
      fromDate: widget.fromDate,
      toDate: widget.toDate,
      month: widget.month,
      year: widget.year,
      status: status,
      pageNumber: page,
      pageSize: _pageSize,
      clearPrevious: false,
    );

    if (!mounted) return;

    setState(() {
      _isInitialLoading = false;
      _isLoadingMore = false;
      _loadingByStatus[status] = false;
      _pagesByStatus[status] = page;

      if (result != null) {
        final items = result.data;
        if (page == 1) {
          _cacheByStatus[status] = List<ClassAttendanceStudentItem>.from(items);
        } else {
          _cacheByStatus[status] = [
            ...(_cacheByStatus[status] ?? []),
            ...items,
          ];
        }
        _metadataByStatus[status] = result.metadata;

        // Populate persistent session info from first available record
        final firstWithDetails = items.firstWhereOrNull(
          (s) => s.attendedBy.isNotEmpty || s.attdMode.isNotEmpty,
        );
        if (firstWithDetails != null) {
          if (firstWithDetails.attendedBy.isNotEmpty) {
            _sessionAttendedBy = firstWithDetails.attendedBy;
          }
          if (firstWithDetails.attdMode.isNotEmpty) {
            _sessionAttdMode = firstWithDetails.attdMode;
          }
          if (firstWithDetails.period.isNotEmpty) {
            _sessionPeriod = firstWithDetails.period;
          }
          if (firstWithDetails.time.isNotEmpty) {
            _sessionTime = firstWithDetails.time;
          }
        }

        // If this was the 'All' fetch and all items arrived in one page,
        // pre-seed Present and Absent tabs for instant switching
        if (status == '' &&
            result.metadata != null &&
            result.metadata!.total <= items.length) {
          final pList = items.where((s) => s.isPresent).toList();
          final aList = items.where((s) => s.isAbsent).toList();

          _cacheByStatus.putIfAbsent('P', () => pList);
          _metadataByStatus.putIfAbsent(
            'P',
            () => Metadata(total: pList.length, page: 1, pagesize: _pageSize),
          );

          _cacheByStatus.putIfAbsent('A', () => aList);
          _metadataByStatus.putIfAbsent(
            'A',
            () => Metadata(total: aList.length, page: 1, pagesize: _pageSize),
          );
        }
      }
    });
  }

  void _onStatusTabChanged(String statusValue) {
    if (_selectedStatus == statusValue) return;

    setState(() {
      _selectedStatus = statusValue;
    });

    // 1. If we already have the cache for this status tab, display instantly!
    if (_cacheByStatus.containsKey(statusValue)) {
      return;
    }

    // 2. If 'All' is loaded and has all items, filter instantly from 'All'
    final allList = _cacheByStatus[''];
    final allMeta = _metadataByStatus[''];
    if (allList != null && allMeta != null && allMeta.total <= allList.length) {
      setState(() {
        if (statusValue == 'P') {
          final pList = allList.where((s) => s.isPresent).toList();
          _cacheByStatus['P'] = pList;
          _metadataByStatus['P'] = Metadata(
            total: pList.length,
            page: 1,
            pagesize: _pageSize,
          );
        } else if (statusValue == 'A') {
          final aList = allList.where((s) => s.isAbsent).toList();
          _cacheByStatus['A'] = aList;
          _metadataByStatus['A'] = Metadata(
            total: aList.length,
            page: 1,
            pagesize: _pageSize,
          );
        }
      });
      return;
    }

    // 3. Otherwise fetch from API smoothly in background without layout shift
    _fetchPage(status: statusValue, page: 1);
  }

  Future<void> _refresh() async {
    _cacheByStatus.remove(_selectedStatus);
    await _fetchPage(status: _selectedStatus, page: 1);
  }

  String get _dateSubtitle {
    switch (widget.reportMode) {
      case FilterMode.bydate:
        final d = widget.fromDate ?? DateTime.now();
        return DateFormat('dd MMM yyyy').format(d);
      case FilterMode.bymonth:
        final m = widget.month ?? '';
        final y = widget.year ?? '';
        return 'Month: $m/$y';
      case FilterMode.byperiod:
        final f = DateFormat('dd MMM yyyy');
        final s = widget.fromDate != null ? f.format(widget.fromDate!) : '';
        final e = widget.toDate != null ? f.format(widget.toDate!) : '';
        return '$s – $e';
    }
  }

  /// Persistent session info card that stays stable across tab switches
  Widget _buildSessionInfoCard(ThemeData theme) {
    final hasDetails =
        _sessionAttendedBy != null ||
        _sessionAttdMode != null ||
        _sessionPeriod != null ||
        _sessionTime != null;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.person_outline_rounded,
                size: 16,
                color: theme.primaryColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _sessionAttendedBy != null
                      ? 'Attended by: $_sessionAttendedBy'
                      : 'Class Attendance Log',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_sessionAttdMode != null && _sessionAttdMode!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: theme.primaryColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    _sessionAttdMode!,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: theme.primaryColor,
                    ),
                  ),
                ),
            ],
          ),
          if (hasDetails &&
              (_sessionPeriod != null || _sessionTime != null)) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (_sessionPeriod != null && _sessionPeriod!.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(right: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 13,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Period $_sessionPeriod',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_sessionTime != null && _sessionTime!.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 13,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _sessionTime!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Status filter tabs with dynamic counts and zero layout shift
  Widget _buildStatusFilterTabs(ThemeData theme) {
    // Determine counts for each tab
    final allCount = _metadataByStatus['']?.total ?? _cacheByStatus['']?.length;

    int? presentCount;
    if (_metadataByStatus['P'] != null) {
      presentCount = _metadataByStatus['P']!.total;
    } else if (_cacheByStatus['P'] != null) {
      presentCount = _cacheByStatus['P']!.length;
    } else if (_cacheByStatus[''] != null) {
      presentCount = _cacheByStatus['']!.where((s) => s.isPresent).length;
    }

    int? absentCount;
    if (_metadataByStatus['A'] != null) {
      absentCount = _metadataByStatus['A']!.total;
    } else if (_cacheByStatus['A'] != null) {
      absentCount = _cacheByStatus['A']!.length;
    } else if (_cacheByStatus[''] != null) {
      absentCount = _cacheByStatus['']!.where((s) => s.isAbsent).length;
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _buildFilterChip(
            label: 'All',
            count: allCount,
            statusValue: '',
            activeColor: theme.primaryColor,
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'Present',
            count: presentCount,
            statusValue: 'P',
            activeColor: const Color(0xFF10B981),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'Absent',
            count: absentCount,
            statusValue: 'A',
            activeColor: const Color(0xFFEF4444),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required int? count,
    required String statusValue,
    required Color activeColor,
  }) {
    final isSelected = _selectedStatus == statusValue;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _onStatusTabChanged(statusValue),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected
                ? activeColor.withValues(alpha: 0.12)
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? activeColor : Colors.transparent,
              width: 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? activeColor : Colors.grey.shade700,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? activeColor.withValues(alpha: 0.2)
                        : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? activeColor : Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    String message = 'No student attendance records found.';
    IconData icon = Icons.people_outline_rounded;
    Color iconColor = Colors.grey.shade400;

    if (_selectedStatus == 'A') {
      message =
          'All Students Present!\nNo absentees recorded for this session.';
      icon = Icons.check_circle_outline_rounded;
      iconColor = const Color(0xFF10B981);
    } else if (_selectedStatus == 'P') {
      message = 'No present students recorded for this filter.';
      icon = Icons.info_outline_rounded;
      iconColor = Colors.grey.shade500;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 54, color: iconColor),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentRecordCard(
    ClassAttendanceStudentItem student,
    ThemeData theme,
  ) {
    final isPresent = student.isPresent;
    final statusColor = isPresent
        ? const Color(0xFF10B981)
        : const Color(0xFFEF4444);
    final statusBg = isPresent
        ? const Color(0xFFECFDF5)
        : const Color(0xFFFEF2F2);
    final initial = student.studentName.isNotEmpty
        ? student.studentName[0].toUpperCase()
        : 'S';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Student Avatar
          CircleAvatar(
            radius: 22,
            backgroundColor: statusColor.withValues(alpha: 0.12),
            child: Text(
              initial,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Student Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.studentName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    if (student.admissionNumber.isNotEmpty)
                      Text(
                        'Adm: ${student.admissionNumber}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    if (student.time.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        '• ${student.time}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ],
                ),
                if (student.attdMode.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Mode: ${student.attdMode}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ],
            ),
          ),

          // Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPresent ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  size: 15,
                  color: statusColor,
                ),
                const SizedBox(width: 5),
                Text(
                  isPresent ? 'PRESENT' : 'ABSENT',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentStudents = _cacheByStatus[_selectedStatus] ?? [];
    final currentMetadata = _metadataByStatus[_selectedStatus];
    final isTabLoading = _loadingByStatus[_selectedStatus] ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Standard ${widget.standard} - Sec ${widget.section}'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              _dateSubtitle,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onPrimary.withValues(alpha: 0.88),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Persistent Session Info Banner (Never shifts layout)
          _buildSessionInfoCard(theme),

          // Status Filter Tabs with Counts (Fixed Position)
          _buildStatusFilterTabs(theme),

          // Thin Loading Indicator for Background Tab Transitions
          if (isTabLoading)
            LinearProgressIndicator(
              minHeight: 2.5,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
            )
          else
            const SizedBox(height: 2.5),

          // Student Records List Area
          Expanded(
            child: _isInitialLoading && currentStudents.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _refresh,
                    child: currentStudents.isEmpty
                        ? _buildEmptyState()
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 10),
                            itemCount: currentStudents.length + 1,
                            itemBuilder: (context, index) {
                              if (index < currentStudents.length) {
                                final student = currentStudents[index];
                                return _buildStudentRecordCard(student, theme);
                              }

                              // Pagination Load More
                              if (_isLoadingMore) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }

                              final totalItems =
                                  currentMetadata?.total ??
                                  currentStudents.length;
                              if (currentStudents.length < totalItems) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
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
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        minimumSize: const Size(180, 44),
                                        elevation: 0,
                                      ),
                                      onPressed: () {
                                        final nextPage =
                                            (_pagesByStatus[_selectedStatus] ??
                                                1) +
                                            1;
                                        _fetchPage(
                                          status: _selectedStatus,
                                          page: nextPage,
                                          isLoadingMore: true,
                                        );
                                      },
                                      icon: const Icon(
                                        Icons.expand_more_rounded,
                                      ),
                                      label: Text(
                                        'Load More (${currentStudents.length} of $totalItems)',
                                      ),
                                    ),
                                  ),
                                );
                              }

                              return const SizedBox(height: 12);
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}
