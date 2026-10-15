import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/leave_balance.dart';
import '../../models/leave_request.dart';
import '../../providers/leave_provider.dart';
import '../../services/hive_service.dart';

class LeaveRequestPage extends StatefulWidget {
  const LeaveRequestPage({super.key, this.initialLeaveTypeFid});

  final int? initialLeaveTypeFid;

  @override
  State<LeaveRequestPage> createState() => _LeaveRequestPageState();
}

class _LeaveRequestPageState extends State<LeaveRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();

  LeaveBalance? _selectedLeaveType;
  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();
  bool _isHalfDay = false;

  final DateFormat _displayDateFormat = DateFormat('EEE, dd MMM yyyy');
  final DateFormat _apiDateFormat = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<LeaveProvider>();
      if (provider.leaveBalances.isEmpty) {
        provider.fetchLeaveBalances();
      }
    });
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  LeaveBalance? _resolveSelectedLeaveType(List<LeaveBalance> balances) {
    if (balances.isEmpty) return null;

    if (_selectedLeaveType != null) {
      final matching = balances.where(
        (b) => b.leavetypeFid == _selectedLeaveType!.leavetypeFid,
      );
      if (matching.isNotEmpty) return matching.first;
    }

    if (widget.initialLeaveTypeFid != null) {
      final found = balances.where(
        (b) => b.leavetypeFid == widget.initialLeaveTypeFid,
      );
      if (found.isNotEmpty) return found.first;
    }

    final accessible = balances.where((b) => b.isEmpAccess).toList();
    if (accessible.isNotEmpty) return accessible.first;
    return balances.first;
  }

  double get _calculatedDays {
    if (_isHalfDay) return 0.5;
    if (_toDate.isBefore(_fromDate)) return 0;
    return (_toDate.difference(_fromDate).inDays + 1).toDouble();
  }

  String get _formattedDays {
    final days = _calculatedDays;
    if (days == days.roundToDouble()) {
      return days.toInt().toString();
    }
    return days.toString();
  }

  Future<void> _selectFromDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 2),
    );
    if (picked != null) {
      setState(() {
        _fromDate = picked;
        if (_toDate.isBefore(_fromDate) || _isHalfDay) {
          _toDate = _fromDate;
        }
      });
    }
  }

  Future<void> _selectToDate(BuildContext context) async {
    if (_isHalfDay) return;
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate.isBefore(_fromDate) ? _fromDate : _toDate,
      firstDate: _fromDate,
      lastDate: DateTime(DateTime.now().year + 2),
    );
    if (picked != null) {
      setState(() => _toDate = picked);
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    final selectedType =
        _selectedLeaveType ??
        _resolveSelectedLeaveType(context.read<LeaveProvider>().leaveBalances);
    if (selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a leave category.')),
      );
      return;
    }

    final currentUser = HiveService.currentUser;
    final empId = currentUser?.id ?? 0;
    if (empId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User session not found. Please log in again.'),
        ),
      );
      return;
    }

    final payload = LeaveRequestPayload(
      leavetypeFid: selectedType.leavetypeFid,
      leavetype: selectedType.leavetype,
      leavebalance: selectedType.balanceLeave,
      employeeId: 241,
      fromdate: _apiDateFormat.format(_fromDate),
      todate: _apiDateFormat.format(_isHalfDay ? _fromDate : _toDate),
      noofdays: _isHalfDay ? 1 : (_toDate.difference(_fromDate).inDays + 1),
      reason: _reasonController.text.trim(),
      halfday: _isHalfDay,
      createdby: 241,
    );

    final provider = context.read<LeaveProvider>();
    final success = await provider.submitLeaveRequest(payload);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Leave request submitted successfully!'),
          backgroundColor: Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop();
    } else {
      final error = provider.errorMessage ?? 'Failed to submit leave request.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('Leave Request')),
      body: Consumer<LeaveProvider>(
        builder: (context, provider, _) {
          final balances = provider.leaveBalances;
          if (balances.isNotEmpty) {
            _selectedLeaveType = _resolveSelectedLeaveType(balances);
          }

          if (provider.loading && balances.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Loading leave quotas...',
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Leave Type Selector Card
                  _buildSectionTitle('Leave Category'),
                  const SizedBox(height: 8),
                  _buildLeaveTypeDropdown(balances),
                  const SizedBox(height: 16),

                  // Balance Overview Banner
                  if (_selectedLeaveType != null) ...[
                    _buildBalancePreviewBanner(_selectedLeaveType!),
                    const SizedBox(height: 20),
                  ],

                  // Date Selection Section
                  _buildSectionTitle('Dates & Duration'),
                  const SizedBox(height: 8),
                  _buildDateSelectors(context),
                  const SizedBox(height: 12),

                  // Half Day Switch Card
                  _buildHalfDayToggle(),
                  const SizedBox(height: 20),

                  // Reason Field
                  _buildSectionTitle('Reason for Leave'),
                  const SizedBox(height: 8),
                  _buildReasonField(),
                  const SizedBox(height: 28),

                  // Submit Button
                  _buildSubmitButton(provider),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: Color(0xFF0F172A),
      ),
    );
  }

  Widget _buildLeaveTypeDropdown(List<LeaveBalance> balances) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<LeaveBalance>(
          isExpanded: true,
          value: _selectedLeaveType,
          hint: const Text(
            'Select Leave Type',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
          ),
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          items: balances.map((item) {
            return DropdownMenuItem<LeaveBalance>(
              value: item,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.leavetype,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${item.balanceLeave}d left',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF059669),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() => _selectedLeaveType = val);
            }
          },
        ),
      ),
    );
  }

  Widget _buildBalancePreviewBanner(LeaveBalance leave) {
    final available = leave.remainingDays;
    final requested = _calculatedDays;
    final projected = available - requested;
    final isExceeded = projected < 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isExceeded ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isExceeded ? const Color(0xFFFCA5A5) : const Color(0xFFBBF7D0),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isExceeded
                ? Icons.warning_amber_rounded
                : Icons.check_circle_outline_rounded,
            color: isExceeded
                ? const Color(0xFFDC2626)
                : const Color(0xFF16A34A),
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isExceeded
                      ? 'Requested days exceed available quota'
                      : 'Quota validation passed',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isExceeded
                        ? const Color(0xFFB91C1C)
                        : const Color(0xFF15803D),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Available: ${leave.balanceLeave}d • Requesting: ${_formattedDays}d • Remaining: ${projected < 0 ? 0 : (projected == projected.roundToDouble() ? projected.toInt() : projected)}d',
                  style: TextStyle(
                    fontSize: 12,
                    color: isExceeded
                        ? const Color(0xFF991B1B)
                        : const Color(0xFF166534),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelectors(BuildContext context) {
    return Row(
      children: [
        // From Date
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _selectFromDate(context),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'From Date',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_rounded,
                        size: 16,
                        color: Color(0xFF0284C7),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _displayDateFormat.format(_fromDate),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),

        // To Date
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _isHalfDay ? null : () => _selectToDate(context),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isHalfDay ? const Color(0xFFF1F5F9) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isHalfDay ? 'To Date (Half Day)' : 'To Date',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.event_available_rounded,
                        size: 16,
                        color: _isHalfDay
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF0284C7),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _displayDateFormat.format(
                            _isHalfDay ? _fromDate : _toDate,
                          ),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _isHalfDay
                                ? const Color(0xFF64748B)
                                : const Color(0xFF0F172A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHalfDayToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(Icons.timelapse_rounded, size: 20, color: Color(0xFFD97706)),
              SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Half Day Leave',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    'Apply for 0.5 day only',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ],
          ),
          Switch.adaptive(
            value: _isHalfDay,
            activeTrackColor: const Color(0xFF0284C7),
            onChanged: (val) {
              setState(() {
                _isHalfDay = val;
                if (_isHalfDay) {
                  _toDate = _fromDate;
                }
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReasonField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: TextFormField(
        controller: _reasonController,
        maxLines: 4,
        style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
        decoration: const InputDecoration(
          hintText: 'Enter specific reason for taking leave...',
          hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
          contentPadding: EdgeInsets.all(14),
          border: InputBorder.none,
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Please enter a reason for this leave request.';
          }
          if (value.trim().length < 3) {
            return 'Reason should be at least 3 characters.';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildSubmitButton(LeaveProvider provider) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0284C7),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 1,
        ),
        onPressed: provider.submitting ? null : _handleSubmit,
        child: provider.submitting
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.send_rounded, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Submit Request ($_formattedDays ${_calculatedDays == 1 ? "Day" : "Days"})',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
