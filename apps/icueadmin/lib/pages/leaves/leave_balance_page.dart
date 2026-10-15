import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/leave_balance.dart';
import '../../providers/leave_provider.dart';
import '../../widgets/no_data_widget.dart';

class LeaveBalancePage extends StatefulWidget {
  const LeaveBalancePage({super.key, this.initialYear});

  final int? initialYear;

  @override
  State<LeaveBalancePage> createState() => _LeaveBalancePageState();
}

class _LeaveBalancePageState extends State<LeaveBalancePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<LeaveProvider>();
      provider.fetchLeaveBalances(year: widget.initialYear);
    });
  }

  IconData _getIconForLeave(String leaveType) {
    final type = leaveType.toLowerCase();
    if (type.contains('casual') || type.contains('(cl)')) {
      return Icons.beach_access_rounded;
    } else if (type.contains('sick') || type.contains('medical')) {
      return Icons.medical_services_rounded;
    } else if (type.contains('earned') || type.contains('(el)')) {
      return Icons.verified_rounded;
    } else if (type.contains('maternity')) {
      return Icons.family_restroom_rounded;
    } else if (type.contains('paternity')) {
      return Icons.child_care_rounded;
    } else if (type.contains('bereavement')) {
      return Icons.favorite_border_rounded;
    } else if (type.contains('marriage')) {
      return Icons.celebration_rounded;
    } else if (type.contains('assigned')) {
      return Icons.assignment_turned_in_rounded;
    }
    return Icons.event_note_rounded;
  }

  Color _getColorForLeave(String leaveType) {
    final type = leaveType.toLowerCase();
    if (type.contains('casual') || type.contains('(cl)')) {
      return const Color(0xFF0284C7);
    } else if (type.contains('sick') || type.contains('medical')) {
      return const Color(0xFFE11D48);
    } else if (type.contains('earned') || type.contains('(el)')) {
      return const Color(0xFFD97706);
    } else if (type.contains('maternity')) {
      return const Color(0xFF9333EA);
    } else if (type.contains('paternity')) {
      return const Color(0xFF4F46E5);
    } else if (type.contains('bereavement')) {
      return const Color(0xFF475569);
    } else if (type.contains('marriage')) {
      return const Color(0xFFDB2777);
    } else if (type.contains('assigned')) {
      return const Color(0xFF0D9488);
    }
    return const Color(0xFF2563EB);
  }

  String _formatDays(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Leave Balance'),
        actions: [
          Consumer<LeaveProvider>(
            builder: (context, provider, _) {
              final currentYear = DateTime.now().year;
              final baseYears = {
                currentYear - 2,
                currentYear - 1,
                currentYear,
                currentYear + 1,
              };
              if (!baseYears.contains(provider.selectedYear)) {
                baseYears.add(provider.selectedYear);
              }
              final years = baseYears.toList()..sort();

              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Material(
                      color: Colors.transparent,
                      child: PopupMenuButton<int>(
                        tooltip: 'Select Year',
                        elevation: 6,
                        shadowColor: Colors.black.withValues(alpha: 0.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        color: Colors.white,
                        position: PopupMenuPosition.under,
                        offset: const Offset(0, 6),
                        onSelected: (year) {
                          provider.setYear(year);
                        },
                        itemBuilder: (context) {
                          final theme = Theme.of(context);
                          return years.map((year) {
                            final isSelected = year == provider.selectedYear;
                            return PopupMenuItem<int>(
                              value: year,
                              height: 42,
                              child: Row(
                                children: [
                                  Icon(
                                    isSelected
                                        ? Icons.calendar_month_rounded
                                        : Icons.calendar_today_outlined,
                                    size: 16,
                                    color: isSelected
                                        ? theme.primaryColor
                                        : const Color(0xFF94A3B8),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    '$year',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? theme.primaryColor
                                          : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const Spacer(),
                                  if (isSelected)
                                    Icon(
                                      Icons.check_rounded,
                                      size: 18,
                                      color: theme.primaryColor,
                                    ),
                                ],
                              ),
                            );
                          }).toList();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.calendar_today_rounded,
                                size: 13,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${provider.selectedYear}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<LeaveProvider>(
        builder: (context, provider, _) {
          if (provider.loading && provider.leaveBalances.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Loading leave balances...',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
                  ),
                ],
              ),
            );
          }

          if (provider.errorMessage != null && provider.leaveBalances.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 56,
                      color: Color(0xFFEF4444),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      provider.errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        provider.fetchLeaveBalances(refresh: true);
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final displayed = provider.displayedLeaves;

          return RefreshIndicator(
            onRefresh: () async {
              await provider.fetchLeaveBalances(refresh: true);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Summary Metrics
                  _buildSummarySection(context, provider),
                  const SizedBox(height: 20),

                  // Filter Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Leave Categories (${displayed.length})',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      FilterChip(
                        selected: provider.onlyAccessibleLeaves,
                        label: const Text('Accessible Only'),
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: provider.onlyAccessibleLeaves
                              ? Colors.white
                              : const Color(0xFF334155),
                        ),
                        selectedColor: const Color(0xFF0284C7),
                        checkmarkColor: Colors.white,
                        onSelected: (val) {
                          provider.setFilterAccessibleOnly(val);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Leave Cards List
                  if (displayed.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: NoDataWidget(
                        msg: 'No leave records found for selected filter.',
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: displayed.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        return _buildLeaveCard(context, displayed[index]);
                      },
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummarySection(BuildContext context, LeaveProvider provider) {
    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            title: 'Total Quota',
            value: _formatDays(provider.totalAllocated),
            suffix: 'Days',
            color: const Color(0xFF0284C7),
            bgColor: const Color(0xFFEFF6FF),
            icon: Icons.pie_chart_outline_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMetricCard(
            title: 'Taken',
            value: _formatDays(provider.totalTaken),
            suffix: 'Days',
            color: const Color(0xFFD97706),
            bgColor: const Color(0xFFFFFBEB),
            icon: Icons.event_busy_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMetricCard(
            title: 'Balance',
            value: _formatDays(provider.totalBalance),
            suffix: 'Days',
            color: const Color(0xFF059669),
            bgColor: const Color(0xFFECFDF5),
            icon: Icons.check_circle_outline_rounded,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String suffix,
    required Color color,
    required Color bgColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 14, color: color),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                suffix,
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveCard(BuildContext context, LeaveBalance leave) {
    final themeColor = _getColorForLeave(leave.leavetype);
    final icon = _getIconForLeave(leave.leavetype);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: themeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 22, color: themeColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              leave.leavetype,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: leave.isEmpAccess
                                  ? const Color(0xFFECFDF5)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              leave.isEmpAccess ? 'Accessible' : 'Restricted',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: leave.isEmpAccess
                                    ? const Color(0xFF059669)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (leave.description != null &&
                          leave.description!.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          leave.description!.trim(),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetricSubColumn(
                    label: 'Allocated',
                    value: '${leave.noOfDays} d',
                    color: const Color(0xFF334155),
                  ),
                ),
                Container(height: 24, width: 1, color: const Color(0xFFE2E8F0)),
                Expanded(
                  child: _buildMetricSubColumn(
                    label: 'Taken',
                    value: '${leave.leaveTaken} d',
                    color: const Color(0xFFD97706),
                  ),
                ),
                Container(height: 24, width: 1, color: const Color(0xFFE2E8F0)),
                Expanded(
                  child: _buildMetricSubColumn(
                    label: 'Balance',
                    value: '${leave.balanceLeave} d',
                    color: const Color(0xFF059669),
                    isHighlight: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricSubColumn({
    required String label,
    required String value,
    required Color color,
    bool isHighlight = false,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: isHighlight
              ? const EdgeInsets.symmetric(horizontal: 8, vertical: 2)
              : EdgeInsets.zero,
          decoration: isHighlight
              ? BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(6),
                )
              : null,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
