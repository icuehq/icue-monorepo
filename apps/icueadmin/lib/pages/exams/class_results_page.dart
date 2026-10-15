import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/exam_results.dart';
import '../../providers/exam_provider.dart';
import 'exam_helpers.dart';

class ClassResultsPage extends StatefulWidget {
  const ClassResultsPage({
    super.key,
    required this.academicYear,
    required this.examName,
    required this.classOption,
    required this.section,
    this.initialStudentId,
    this.initialStudentName,
  });

  final String academicYear;
  final String examName;
  final ExamClassOption classOption;
  final String section;
  final int? initialStudentId;
  final String? initialStudentName;

  @override
  State<ClassResultsPage> createState() => _ClassResultsPageState();
}

class _ClassResultsPageState extends State<ClassResultsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'ALL'; // 'ALL', 'PASSED', 'FAILED', 'NA'
  String _sortBy = 'RANK'; // 'RANK', 'PERCENTAGE', 'NAME', 'ROLL'
  int? _activeStudentFilterId;
  String? _activeStudentFilterName;
  final Set<int> _expandedStudentIds = {};

  @override
  void initState() {
    super.initState();
    _activeStudentFilterId = widget.initialStudentId;
    _activeStudentFilterName = widget.initialStudentName;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && context.read<ExamProvider>().results.isEmpty) {
        _refreshResults();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshResults() async {
    final examProvider = context.read<ExamProvider>();
    await examProvider.getExamResults(
      academicYear: widget.academicYear,
      examName: widget.examName,
      classId: widget.classOption.classId,
      section: widget.section,
    );
  }

  List<ExamResult> _getFilteredAndSortedResults(List<ExamResult> allResults) {
    var list = List<ExamResult>.from(allResults);

    // 1. Single student filter if selected from configuration
    if (_activeStudentFilterId != null) {
      list = list.where((r) => r.studentId == _activeStudentFilterId).toList();
    }

    // 2. Search query (matches Student Name, Roll No, or Admission No)
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      list = list.where((r) {
        final nameMatch = r.studentName.toLowerCase().contains(q);
        final rollMatch = r.rollNo?.toLowerCase().contains(q) ?? false;
        final admMatch = r.admissionNumber?.toLowerCase().contains(q) ?? false;
        return nameMatch || rollMatch || admMatch;
      }).toList();
    }

    // 3. Status filter
    switch (_statusFilter) {
      case 'PASSED':
        list = list.where((r) => r.isPassed).toList();
        break;
      case 'FAILED':
        list = list.where((r) => r.isFailed).toList();
        break;
      case 'NA':
        list = list
            .where(
              (r) =>
                  r.result?.toUpperCase() == 'N/A' ||
                  r.result?.toUpperCase() == 'NA' ||
                  r.status?.toUpperCase() == 'NA',
            )
            .toList();
        break;
      case 'ALL':
      default:
        break;
    }

    // 4. Sort
    switch (_sortBy) {
      case 'PERCENTAGE':
        list.sort((a, b) => (b.percentage ?? 0).compareTo(a.percentage ?? 0));
        break;
      case 'NAME':
        list.sort(
          (a, b) => a.studentName.toLowerCase().compareTo(
            b.studentName.toLowerCase(),
          ),
        );
        break;
      case 'ROLL':
        list.sort((a, b) => (a.rollNo ?? '').compareTo(b.rollNo ?? ''));
        break;
      case 'RANK':
      default:
        list.sort((a, b) => (a.rank ?? 9999).compareTo(b.rank ?? 9999));
        break;
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final examProvider = context.watch<ExamProvider>();
    final allResults = examProvider.results;
    final filteredResults = _getFilteredAndSortedResults(allResults);

    // KPI Metrics calculation
    final totalStudents = allResults.length;
    final passCount = allResults.where((r) => r.isPassed).length;
    final failCount = allResults.where((r) => r.isFailed).length;
    final naCount = allResults
        .where(
          (r) =>
              r.result?.toUpperCase() == 'N/A' ||
              r.result?.toUpperCase() == 'NA' ||
              r.status?.toUpperCase() == 'NA',
        )
        .length;
    final evaluatedStudents = totalStudents - naCount;
    final passPercentage = evaluatedStudents > 0
        ? ((passCount / evaluatedStudents) * 100).toStringAsFixed(1)
        : (totalStudents > 0
              ? ((passCount / totalStudents) * 100).toStringAsFixed(1)
              : '0.0');

    final validPercentages = allResults
        .where((r) => r.percentage != null)
        .map((r) => r.percentage!)
        .toList();
    final classAverage = validPercentages.isNotEmpty
        ? (validPercentages.reduce((a, b) => a + b) / validPercentages.length)
              .toStringAsFixed(1)
        : '0.0';

    ExamResult? topScorer;
    if (validPercentages.isNotEmpty) {
      final sortedList = List<ExamResult>.from(allResults)
        ..sort((a, b) => (b.percentage ?? 0).compareTo(a.percentage ?? 0));
      topScorer = sortedList.firstOrNull;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Class Results',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${widget.classOption.standard} • Section ${widget.section}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: examProvider.loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _refreshResults,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // Context & Criteria Header Bar
                    SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.school_outlined,
                              size: 18,
                              color: theme.primaryColor,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${widget.examName} (${widget.academicYear})',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '$totalStudents Students',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // KPI Summary Cards
                    if (allResults.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  // Pass Rate KPI
                                  Expanded(
                                    child: _buildKpiCard(
                                      title: 'Pass Rate',
                                      value: '$passPercentage%',
                                      subtitle:
                                          '$passCount Pass • $failCount Fail',
                                      icon: Icons.check_circle_outline,
                                      iconColor: const Color(0xFF10B981),
                                      bgColor: const Color(0xFFF0FDF4),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  // Class Average KPI
                                  Expanded(
                                    child: _buildKpiCard(
                                      title: 'Class Average',
                                      value: '$classAverage%',
                                      subtitle:
                                          'Across $totalStudents students',
                                      icon: Icons.insights_outlined,
                                      iconColor: const Color(0xFF3B82F6),
                                      bgColor: const Color(0xFFEFF6FF),
                                    ),
                                  ),
                                ],
                              ),
                              if (topScorer != null &&
                                  topScorer.percentage != null) ...[
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFFFFBEB),
                                        Color(0xFFFEF3C7),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: const Color(0xFFFDE68A),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.emoji_events_rounded,
                                        color: Color(0xFFD97706),
                                        size: 24,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'TOP SCORER (Rank #1)',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 0.5,
                                                color: Color(0xFF92400E),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              topScorer.studentName,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF78350F),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.05,
                                              ),
                                              blurRadius: 4,
                                            ),
                                          ],
                                        ),
                                        child: Text(
                                          topScorer.displayPercentage,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFFB45309),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                    // Student Filter banner (if active)
                    if (_activeStudentFilterId != null)
                      SliverToBoxAdapter(
                        child: Container(
                          margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.person_outline,
                                size: 16,
                                color: Color(0xFF475569),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Showing result for: ${_activeStudentFilterName ?? "Student"}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    _activeStudentFilterId = null;
                                    _activeStudentFilterName = null;
                                  });
                                },
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'View All',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF2563EB),
                                        ),
                                      ),
                                      SizedBox(width: 2),
                                      Icon(
                                        Icons.close,
                                        size: 14,
                                        color: Color(0xFF2563EB),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Search Bar & Sort Control
                    if (allResults.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                          child: Row(
                            children: [
                              // Search TextField
                              Expanded(
                                child: Container(
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFFCBD5E1),
                                    ),
                                  ),
                                  child: TextField(
                                    controller: _searchController,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF0F172A),
                                    ),
                                    decoration: InputDecoration(
                                      hintText:
                                          'Search student, roll or adm...',
                                      hintStyle: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade400,
                                      ),
                                      prefixIcon: const Icon(
                                        Icons.search,
                                        size: 18,
                                        color: Color(0xFF64748B),
                                      ),
                                      suffixIcon: _searchQuery.isNotEmpty
                                          ? IconButton(
                                              icon: const Icon(
                                                Icons.clear,
                                                size: 16,
                                                color: Color(0xFF64748B),
                                              ),
                                              onPressed: () {
                                                _searchController.clear();
                                                setState(
                                                  () => _searchQuery = '',
                                                );
                                              },
                                            )
                                          : null,
                                      border: InputBorder.none,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            vertical: 10,
                                          ),
                                    ),
                                    onChanged: (val) =>
                                        setState(() => _searchQuery = val),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Sort Dropdown
                              Container(
                                height: 42,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFFCBD5E1),
                                  ),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _sortBy,
                                    icon: const Icon(
                                      Icons.sort_rounded,
                                      size: 18,
                                      color: Color(0xFF64748B),
                                    ),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1E293B),
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'RANK',
                                        child: Text('Rank'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'PERCENTAGE',
                                        child: Text('Score %'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'NAME',
                                        child: Text('Name'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'ROLL',
                                        child: Text('Roll No'),
                                      ),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() => _sortBy = val);
                                      }
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Expand / Collapse All Button
                              InkWell(
                                onTap: () {
                                  final allExpanded =
                                      filteredResults.isNotEmpty &&
                                      filteredResults.every(
                                        (r) => _expandedStudentIds.contains(
                                          r.studentId,
                                        ),
                                      );
                                  setState(() {
                                    if (allExpanded) {
                                      _expandedStudentIds.clear();
                                    } else {
                                      _expandedStudentIds.addAll(
                                        filteredResults.map((r) => r.studentId),
                                      );
                                    }
                                  });
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  height: 42,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFFCBD5E1),
                                    ),
                                  ),
                                  child: Builder(
                                    builder: (context) {
                                      final allExpanded =
                                          filteredResults.isNotEmpty &&
                                          filteredResults.every(
                                            (r) => _expandedStudentIds.contains(
                                              r.studentId,
                                            ),
                                          );
                                      return Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            allExpanded
                                                ? Icons.unfold_less
                                                : Icons.unfold_more,
                                            size: 18,
                                            color: const Color(0xFF64748B),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            allExpanded ? 'Collapse' : 'Expand',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF1E293B),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Filter Segment Tabs
                    if (allResults.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          child: Row(
                            children: [
                              _buildFilterTab(
                                title: 'All',
                                count: allResults.length,
                                filterValue: 'ALL',
                                theme: theme,
                              ),
                              const SizedBox(width: 8),
                              _buildFilterTab(
                                title: 'Passed',
                                count: passCount,
                                filterValue: 'PASSED',
                                theme: theme,
                                highlightColor: const Color(0xFF10B981),
                              ),
                              const SizedBox(width: 8),
                              _buildFilterTab(
                                title: 'Failed',
                                count: failCount,
                                filterValue: 'FAILED',
                                theme: theme,
                                highlightColor: const Color(0xFFEF4444),
                              ),
                              if (naCount > 0) ...[
                                const SizedBox(width: 8),
                                _buildFilterTab(
                                  title: 'Exempted',
                                  count: naCount,
                                  filterValue: 'NA',
                                  theme: theme,
                                  highlightColor: const Color(0xFF64748B),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                    // Results List / Empty State
                    if (filteredResults.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.assignment_outlined,
                                  size: 52,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  allResults.isEmpty
                                      ? 'No Results Found'
                                      : 'No Matching Students',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  allResults.isEmpty
                                      ? 'No exam results available for ${widget.classOption.standard} Section ${widget.section}.'
                                      : 'No students match your filter or search criteria.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                if (allResults.isNotEmpty &&
                                    (_searchQuery.isNotEmpty ||
                                        _statusFilter != 'ALL' ||
                                        _activeStudentFilterId != null)) ...[
                                  const SizedBox(height: 16),
                                  OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(120, 36),
                                      side: BorderSide(
                                        color: theme.primaryColor,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _searchQuery = '';
                                        _searchController.clear();
                                        _statusFilter = 'ALL';
                                        _activeStudentFilterId = null;
                                        _activeStudentFilterName = null;
                                      });
                                    },
                                    child: const Text('Clear Filters'),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final result = filteredResults[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _StudentResultCard(
                                result: result,
                                isExpanded: _expandedStudentIds.contains(
                                  result.studentId,
                                ),
                                onToggleExpand: () {
                                  setState(() {
                                    if (_expandedStudentIds.contains(
                                      result.studentId,
                                    )) {
                                      _expandedStudentIds.remove(
                                        result.studentId,
                                      );
                                    } else {
                                      _expandedStudentIds.add(result.studentId);
                                    }
                                  });
                                },
                              ),
                            );
                          }, childCount: filteredResults.length),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildFilterTab({
    required String title,
    required int count,
    required String filterValue,
    required ThemeData theme,
    Color? highlightColor,
  }) {
    final isSelected = _statusFilter == filterValue;
    final color = highlightColor ?? theme.primaryColor;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _statusFilter = filterValue),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? color : const Color(0xFFE2E8F0),
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: iconColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF475569),
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

class _StudentResultCard extends StatelessWidget {
  const _StudentResultCard({
    required this.result,
    required this.isExpanded,
    required this.onToggleExpand,
  });

  final ExamResult result;
  final bool isExpanded;
  final VoidCallback onToggleExpand;

  @override
  Widget build(BuildContext context) {
    final r = result;
    final isPassed = r.isPassed;
    final isResultNA =
        r.result?.toUpperCase() == 'N/A' ||
        r.result?.toUpperCase() == 'NA' ||
        r.status?.toUpperCase() == 'NA';
    final gradeColor = ExamHelpers.getGradeColor(r.grade);
    final resultColor = isResultNA
        ? const Color(0xFF64748B)
        : (isPassed ? const Color(0xFF10B981) : const Color(0xFFEF4444));

    final hasSubjects = r.subjectMarks != null && r.subjectMarks!.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header Row
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: hasSubjects ? onToggleExpand : null,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Rank Badge
                  ExamHelpers.buildRankBadge(r.rank),
                  const SizedBox(width: 10),

                  // Student Name, Roll No & Admission No
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.studentName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            if (r.rollNo != null && r.rollNo!.isNotEmpty) ...[
                              Text(
                                'Roll: ${r.rollNo}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              if (r.admissionNumber != null &&
                                  r.admissionNumber!.isNotEmpty) ...[
                                const Text(
                                  ' • ',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                                Flexible(
                                  child: Text(
                                    'Adm: ${r.admissionNumber}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ],
                            ] else if (r.admissionNumber != null &&
                                r.admissionNumber!.isNotEmpty) ...[
                              Text(
                                'Adm: ${r.admissionNumber}',
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

                  // Total Marks & Percentage
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        r.displayPercentage,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isPassed
                              ? const Color(0xFF0F172A)
                              : const Color(0xFFB91C1C),
                        ),
                      ),
                      if (r.totalMarks != null && r.maximumMarks != null)
                        Text(
                          '${r.totalMarks} / ${r.maximumMarks}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 8),

                  // Grade Badge
                  if (r.grade != null && r.grade!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: gradeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: gradeColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        r.grade!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: gradeColor,
                        ),
                      ),
                    ),
                  const SizedBox(width: 6),

                  // Result Pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: resultColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: resultColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      r.result?.toUpperCase() ?? (isPassed ? 'PASS' : 'FAIL'),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: resultColor,
                      ),
                    ),
                  ),

                  if (hasSubjects) ...[
                    const SizedBox(width: 2),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: const Color(0xFF94A3B8),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Expandable Subject Marks Breakdown
          if (isExpanded && hasSubjects) ...[
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Subject-wise Breakdown',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...r.subjectMarks!.map((sub) {
                    final subPassed = sub.isPassed;
                    final isNotEntered =
                        sub.status?.toUpperCase() == 'NOT_ENTERED';
                    final isAbsent = sub.status?.toUpperCase() == 'ABSENT';
                    final isNA = sub.status?.toUpperCase() == 'NA';

                    String statusLabel;
                    Color statusColor;
                    Color statusBg;

                    if (isAbsent) {
                      statusLabel = 'ABSENT';
                      statusColor = const Color(0xFFEF4444);
                      statusBg = const Color(0xFFFEE2E2);
                    } else if (isNA) {
                      statusLabel = 'N/A';
                      statusColor = const Color(0xFF64748B);
                      statusBg = const Color(0xFFF1F5F9);
                    } else if (isNotEntered) {
                      statusLabel = 'PENDING';
                      statusColor = const Color(0xFFF59E0B);
                      statusBg = const Color(0xFFFEF3C7);
                    } else if (subPassed) {
                      statusLabel = 'PASS';
                      statusColor = const Color(0xFF10B981);
                      statusBg = const Color(0xFFDCFCE7);
                    } else {
                      statusLabel = 'FAIL';
                      statusColor = const Color(0xFFEF4444);
                      statusBg = const Color(0xFFFEE2E2);
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: Text(
                              sub.subject,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              (isAbsent || isNotEntered || isNA) &&
                                      sub.marks == null
                                  ? '-'
                                  : '${sub.marks ?? '-'}/${sub.maximumMarks ?? '-'}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF334155),
                              ),
                            ),
                          ),
                          if (sub.passingMarks != null)
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Pass: ${sub.passingMarks}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: statusBg,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
