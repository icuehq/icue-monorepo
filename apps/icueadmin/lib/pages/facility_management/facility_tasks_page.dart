import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../dialogs/fail_cleaning_task_dialog.dart';
import '../../dialogs/skip_cleaning_task_dialog.dart';
import '../../models/facility_task.dart';
import '../../models/facility_task_status.dart';
import '../../providers/facility_provider.dart';
import '../../utils/app_utils.dart';

class MyCleaningTasksPage extends StatefulWidget {
  const MyCleaningTasksPage({super.key});

  @override
  State<MyCleaningTasksPage> createState() => _MyCleaningTasksPageState();
}

// Alias for backward compatibility
typedef FacilityTasksPage = MyCleaningTasksPage;

class _MyCleaningTasksPageState extends State<MyCleaningTasksPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _statusScrollController = ScrollController();
  DateTime _selectedDate = DateTime.now();
  String _selectedStatusFilter = 'All';

  final List<String> _statusFilters = [
    'All',
    'Pending',
    'InProgress',
    'Completed',
    'Skipped',
    'Failed',
  ];

  final Map<String, GlobalKey> _statusKeys = {
    for (final status in [
      'All',
      'Pending',
      'InProgress',
      'Completed',
      'Skipped',
      'Failed',
    ])
      status: GlobalKey(),
  };

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _fetchTasks();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _statusScrollController.dispose();
    super.dispose();
  }

  void _selectStatusFilter(String status) {
    setState(() {
      _selectedStatusFilter = status;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final keyContext = _statusKeys[status]?.currentContext;
      if (keyContext != null && mounted) {
        Scrollable.ensureVisible(
          keyContext,
          alignment: 0.5,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _fetchTasks() {
    final prov = context.read<FacilityProvider>();
    prov.getCleaningTasks(_selectedDate);
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _fetchTasks();
    }
  }

  void _shiftDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
    _fetchTasks();
  }

  void _openCameraScanner() {
    context.push('/facility-qr-scanner');
  }

  List<FacilityTask> _filterTasks(List<FacilityTask> allTasks) {
    var filtered = allTasks;

    // Filter by status
    if (_selectedStatusFilter != 'All') {
      final targetStatus = FacilityTaskStatus.fromString(_selectedStatusFilter);
      filtered = filtered.where((t) => t.taskStatus == targetStatus).toList();
    }

    // Filter by search query safely
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((t) {
        final nameMatch = t.scheduleName?.toLowerCase().contains(query);
        final userMatch = t.assignedUser?.toLowerCase().contains(query);
        final roleMatch = t.assignedRole?.toLowerCase().contains(query);
        final statusMatch = t.status.toLowerCase().contains(query);
        final idMatch = t.id?.toString().contains(query);
        return (nameMatch ?? false) ||
            (userMatch ?? false) ||
            (roleMatch ?? false) ||
            statusMatch ||
            (idMatch ?? false);
      }).toList();
    }

    return filtered;
  }

  int _getStatusCount(List<FacilityTask> allTasks, String status) {
    if (status == 'All') return allTasks.length;
    final targetStatus = FacilityTaskStatus.fromString(status);
    return allTasks.where((t) => t.taskStatus == targetStatus).length;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prov = context.watch<FacilityProvider>();

    final allTasks = prov.cleaningTasks;
    final displayTasks = _filterTasks(allTasks);

    final isToday = DateUtils.isSameDay(_selectedDate, DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Cleaning Tasks',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCameraScanner,
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Scan QR Code'),
      ),
      body: Column(
        children: [
          // 1. Date Selector Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton.filledTonal(
                  style: IconButton.styleFrom(
                    minimumSize: const Size(36, 36),
                    padding: EdgeInsets.zero,
                  ),
                  icon: const Icon(Icons.chevron_left, size: 22),
                  onPressed: () => _shiftDate(-1),
                  tooltip: 'Previous Day',
                ),
                InkWell(
                  onTap: () => _selectDate(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_month_outlined,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isToday
                              ? 'Today, ${_selectedDate.formattedFullDate()}'
                              : _selectedDate.formattedDayDate(),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        if (isToday) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'TODAY',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  style: IconButton.styleFrom(
                    minimumSize: const Size(36, 36),
                    padding: EdgeInsets.zero,
                  ),
                  icon: const Icon(Icons.chevron_right, size: 22),
                  onPressed: () => _shiftDate(1),
                  tooltip: 'Next Day',
                ),
              ],
            ),
          ),

          // 2. Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search tasks, schedules, assigned user...',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade500,
                  ),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.colorScheme.primary),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  filled: true,
                  fillColor: theme.colorScheme.surface,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),

          // 3. Status Filter Tabs
          SingleChildScrollView(
            controller: _statusScrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: _statusFilters.map((status) {
                final isSelected = _selectedStatusFilter == status;
                final count = _getStatusCount(allTasks, status);
                final label = status == 'InProgress' ? 'In Progress' : status;
                final color = status == 'All'
                    ? theme.colorScheme.primary
                    : FacilityTaskStatus.fromString(status).color;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    key: _statusKeys[status],
                    label: Text(
                      '$label ($count)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: isSelected ? Colors.white : Colors.grey.shade800,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: color,
                    backgroundColor: theme.colorScheme.surface,
                    showCheckmark: false,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected ? color : Colors.grey.shade300,
                      ),
                    ),
                    onSelected: (val) {
                      _selectStatusFilter(status);
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          const Divider(height: 1),

          // 4. Tasks List
          Expanded(
            child: prov.loading && prov.cleaningTasks.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () async => _fetchTasks(),
                    child: displayTasks.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              const SizedBox(height: 50),
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.all(24),
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surface,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.primary
                                              .withValues(alpha: 0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.cleaning_services_outlined,
                                          size: 48,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        _searchController.text.isNotEmpty
                                            ? 'No matching tasks'
                                            : 'No tasks for this date',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _searchController.text.isNotEmpty
                                            ? 'Try searching with a different term or clear filters.'
                                            : 'Scan a facility QR code to check if tasks are assigned.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      FilledButton.icon(
                                        style: FilledButton.styleFrom(
                                          minimumSize: Size.zero,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 20,
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.qr_code_scanner,
                                          size: 18,
                                        ),
                                        label: const Text('Scan Facility QR'),
                                        onPressed: _openCameraScanner,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                            itemCount: displayTasks.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final task = displayTasks[index];
                              return _buildTaskCard(context, task, theme);
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(
    BuildContext context,
    FacilityTask task,
    ThemeData theme,
  ) {
    final status = task.taskStatus;
    final statusColor = status.color;
    final statusIcon = status.icon;
    final isPending = status.isPending;
    final isInProgress = status.isInProgress;
    final taskId = task.id;

    final timeRange =
        (task.scheduledStartTime?.isNotEmpty == true &&
            task.scheduledEndTime?.isNotEmpty == true)
        ? '${task.scheduledStartTime} - ${task.scheduledEndTime}'
        : task.scheduledStartTime;

    return Material(
      color: theme.colorScheme.surface,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.03),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          if (taskId != null) {
            await context.push('/facility-task-detail?taskId=$taskId');
            if (context.mounted) _fetchTasks();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Top Row: Task Name & Status Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.scheduleName ??
                              'Cleaning Task #${task.id ?? ''}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (task.assignedUser?.isNotEmpty == true) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.person_outline,
                                size: 14,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Assigned to: ${task.assignedUser}${task.assignedRole?.isNotEmpty == true ? ' (${task.assignedRole})' : ''}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 13, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          status.label,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // 2. Metadata Row: Time & Template Version
              Wrap(
                spacing: 12,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (timeRange?.isNotEmpty == true)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 13,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          timeRange ?? '',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 13,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        task.scheduledDate.formattedFullDate(fallback: ''),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const Divider(height: 18),

              // 3. Action Buttons Row
              if (taskId != null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (isPending) ...[
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: Size.zero,
                          foregroundColor: const Color(0xFFEA580C),
                          side: const BorderSide(color: Color(0xFFFDBA74)),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => SkipCleaningTaskDialog(
                              taskId: taskId,
                              taskName: task.scheduleName ?? '',
                              onConfirm: (reason) async {
                                final prov = context.read<FacilityProvider>();
                                await prov.skipCleaningTask(
                                  taskId: taskId,
                                  remarks: reason,
                                  context: context,
                                );
                                _fetchTasks();
                              },
                            ),
                          );
                        },
                        child: const Text(
                          'Skip',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          minimumSize: Size.zero,
                          backgroundColor: theme.colorScheme.primary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.play_arrow, size: 15),
                        label: const Text(
                          'Start Task',
                          style: TextStyle(fontSize: 12),
                        ),
                        onPressed: () async {
                          final prov = context.read<FacilityProvider>();
                          final success = await prov.startCleaningTask(
                            taskId,
                            context: context,
                          );
                          if (success && context.mounted) {
                            _fetchTasks();
                            context.push(
                              '/facility-task-detail?taskId=$taskId',
                            );
                          }
                        },
                      ),
                    ] else if (isInProgress) ...[
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: Size.zero,
                          foregroundColor: const Color(0xFFDC2626),
                          side: const BorderSide(color: Color(0xFFFCA5A5)),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => FailCleaningTaskDialog(
                              taskId: taskId,
                              taskName: task.scheduleName ?? '',
                              onConfirm: (reason) async {
                                final prov = context.read<FacilityProvider>();
                                await prov.failCleaningTask(
                                  taskId: taskId,
                                  remarks: reason,
                                  context: context,
                                );
                                _fetchTasks();
                              },
                            ),
                          );
                        },
                        child: const Text(
                          'Report Fail',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          minimumSize: Size.zero,
                          backgroundColor: const Color(0xFF10B981),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.check_circle_outline, size: 15),
                        label: const Text(
                          'Complete',
                          style: TextStyle(fontSize: 12),
                        ),
                        onPressed: () async {
                          await context.push(
                            '/facility-task-detail?taskId=$taskId',
                          );
                          if (context.mounted) _fetchTasks();
                        },
                      ),
                    ] else ...[
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                        ),
                        icon: const Icon(Icons.visibility_outlined, size: 15),
                        label: const Text(
                          'View Details',
                          style: TextStyle(fontSize: 12),
                        ),
                        onPressed: () async {
                          await context.push(
                            '/facility-task-detail?taskId=$taskId',
                          );
                          if (context.mounted) _fetchTasks();
                        },
                      ),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
