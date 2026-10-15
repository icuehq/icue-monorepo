import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/home_assignment.dart';
import '../../models/user_info.dart';
import '../../providers/auth_provider.dart';
import '../../providers/home_assignment_provider.dart';
import '../../services/hive_service.dart';
import '../../widgets/no_data_widget.dart';
import 'create_home_assignment_page.dart';

class HomeAssignmentsPage extends StatefulWidget {
  const HomeAssignmentsPage({super.key});

  @override
  State<HomeAssignmentsPage> createState() => _HomeAssignmentsPageState();
}

class _HomeAssignmentsPageState extends State<HomeAssignmentsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initAndFetch();
    });
  }

  void _initAndFetch() {
    final provider = context.read<HomeAssignmentProvider>();
    final availableClasses = _getAvailableClasses();

    if (availableClasses.isNotEmpty) {
      if (provider.selectedClassId == null) {
        final first = availableClasses.first;
        provider.setFilter(
          classId: first.classId,
          standard: first.standard,
          section: first.sections.firstOrNull,
        );
      }
    }

    provider.getHomeAssignments(context: context);
  }

  List<_ClassFilterOption> _getAvailableClasses() {
    final user = HiveService.currentUser;
    final authProvider = context.read<AuthProvider>();
    final Map<int, _ClassFilterOption> map = {};

    if (user?.classes is List && (user!.classes as List).isNotEmpty) {
      for (final c in user.classes as List) {
        if (c is UserClass && c.classId != 0) {
          if (!map.containsKey(c.classId)) {
            map[c.classId] = _ClassFilterOption(
              classId: c.classId,
              standard: c.standard,
              sections: List<String>.from(c.sections),
            );
          } else {
            final existing = map[c.classId]!;
            for (final sec in c.sections) {
              if (!existing.sections.contains(sec)) {
                existing.sections.add(sec);
              }
            }
          }
        }
      }
    }

    if (map.isEmpty && authProvider.assignedEntityClasses.isNotEmpty) {
      for (final c in authProvider.assignedEntityClasses) {
        if (c.classId != 0) {
          map[c.classId] = _ClassFilterOption(
            classId: c.classId,
            standard: c.standard,
            sections: List<String>.from(c.sections),
          );
        }
      }
    }

    return map.values.toList();
  }

  Future<void> _openCreatePage() async {
    final provider = context.read<HomeAssignmentProvider>();
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreateHomeAssignmentPage(
          initialClassId: provider.selectedClassId,
          initialSection: provider.selectedSection,
        ),
      ),
    );

    if (result == true && mounted) {
      provider.getHomeAssignments(context: context);
    }
  }

  void _showImagePreviewDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Dialog Header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                color: const Color(0xFFF8FAFC),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.image_outlined,
                          size: 20,
                          color: Color(0xFF475569),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Attachment Preview',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 22,
                        color: Color(0xFF64748B),
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),

              // Zoomable Image
              Expanded(
                child: Container(
                  color: const Color(0xFF0F172A),
                  child: InteractiveViewer(
                    maxScale: 4.0,
                    child: Center(
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.contain,
                        placeholder: (_, _) => const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                        errorWidget: (_, _, _) => const Padding(
                          padding: EdgeInsets.all(40),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.broken_image_rounded,
                                size: 48,
                                color: Colors.white54,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Failed to load image',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final availableClasses = _getAvailableClasses();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('Home Assignments')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 3,
        onPressed: _openCreatePage,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'New Homework',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
      body: Consumer<HomeAssignmentProvider>(
        builder: (context, provider, _) {
          final selectedClassObj = availableClasses.firstWhereOrNull(
            (c) => c.classId == provider.selectedClassId,
          );
          final availableSections = selectedClassObj?.sections ?? [];

          return Column(
            children: [
              // Sleek Filter Header (Class, Section, Date)
              _buildFilterHeader(
                context: context,
                theme: theme,
                provider: provider,
                availableClasses: availableClasses,
                availableSections: availableSections,
              ),

              // Homework Content List
              Expanded(
                child: provider.loading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: theme.primaryColor,
                        ),
                      )
                    : RefreshIndicator(
                        color: theme.primaryColor,
                        onRefresh: () => provider.getHomeAssignments(
                          context: context,
                          isRefresh: true,
                        ),
                        child: provider.assignments.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: const [
                                  SizedBox(height: 80),
                                  NoDataWidget(
                                    msg:
                                        'No Home Assignments found for selected date and class.',
                                  ),
                                ],
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  16,
                                  16,
                                  88,
                                ),
                                itemCount: provider.assignments.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 14),
                                itemBuilder: (context, index) {
                                  final item = provider.assignments[index];
                                  return _buildAssignmentCard(
                                    context: context,
                                    theme: theme,
                                    item: item,
                                    cachedImages: provider.cachedDocumentImages,
                                  );
                                },
                              ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterHeader({
    required BuildContext context,
    required ThemeData theme,
    required HomeAssignmentProvider provider,
    required List<_ClassFilterOption> availableClasses,
    required List<String> availableSections,
  }) {
    final dateFormat = DateFormat('EEE, dd MMM yyyy');
    final now = DateTime.now();
    final isToday =
        provider.selectedDate.year == now.year &&
        provider.selectedDate.month == now.month &&
        provider.selectedDate.day == now.day;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
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
          // Class & Section Row
          Row(
            children: [
              // Class dropdown
              Expanded(
                flex: 3,
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
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
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            isExpanded: true,
                            value: provider.selectedClassId,
                            hint: const Text(
                              'Select Class',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            icon: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 20,
                              color: Color(0xFF64748B),
                            ),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                            ),
                            items: availableClasses.map((c) {
                              return DropdownMenuItem<int>(
                                value: c.classId,
                                child: Text(c.standard),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                final match = availableClasses.firstWhereOrNull(
                                  (c) => c.classId == val,
                                );
                                provider.setFilter(
                                  classId: val,
                                  standard: match?.standard,
                                  section: match?.sections.firstOrNull,
                                );
                                provider.getHomeAssignments(context: context);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // Section dropdown
              Expanded(
                flex: 2,
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.groups_outlined,
                        size: 18,
                        color: theme.primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: provider.selectedSection,
                            hint: const Text(
                              'Sec',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            icon: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 20,
                              color: Color(0xFF64748B),
                            ),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                            ),
                            items: availableSections.map((sec) {
                              return DropdownMenuItem<String>(
                                value: sec,
                                child: Text('Sec $sec'),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                provider.setFilter(section: val);
                                provider.getHomeAssignments(context: context);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Date Navigator Strip
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: theme.primaryColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: theme.primaryColor.withValues(alpha: 0.18),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded),
                  color: theme.primaryColor,
                  splashRadius: 20,
                  tooltip: 'Previous Day',
                  onPressed: () {
                    final prevDate = provider.selectedDate.subtract(
                      const Duration(days: 1),
                    );
                    provider.setSelectedDate(prevDate);
                    provider.getHomeAssignments(context: context);
                  },
                ),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: provider.selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      provider.setSelectedDate(picked);
                      if (context.mounted) {
                        provider.getHomeAssignments(context: context);
                      }
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 15,
                          color: theme.primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          dateFormat.format(provider.selectedDate),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: theme.primaryColorDark,
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
                              color: theme.primaryColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Today',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isToday)
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(0, 30),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          foregroundColor: theme.primaryColor,
                        ),
                        onPressed: () {
                          provider.setSelectedDate(DateTime.now());
                          provider.getHomeAssignments(context: context);
                        },
                        child: const Text(
                          'Today',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded),
                      color: theme.primaryColor,
                      splashRadius: 20,
                      tooltip: 'Next Day',
                      onPressed: () {
                        final nextDate = provider.selectedDate.add(
                          const Duration(days: 1),
                        );
                        provider.setSelectedDate(nextDate);
                        provider.getHomeAssignments(context: context);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentCard({
    required BuildContext context,
    required ThemeData theme,
    required HomeAssignment item,
    required Map<String, String> cachedImages,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Meta Row: Subject Badge + Class & Section Chip
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Subject chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.menu_book_rounded,
                            size: 14,
                            color: theme.primaryColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            item.subject,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: theme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Section badge (neutral slate)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        '${item.standard} • Sec ${item.section}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Homework Text
                Text(
                  item.work,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                    height: 1.45,
                  ),
                ),

                // Attachment Thumbnails if any
                if (item.images.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(
                        Icons.attachment_rounded,
                        size: 14,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${item.images.length} ${item.images.length == 1 ? 'Attachment' : 'Attachments'}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 76,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: item.images.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (context, imgIndex) {
                        final docId = item.images[imgIndex];
                        final url = cachedImages[docId];

                        return InkWell(
                          onTap: () {
                            if (url != null && url.isNotEmpty) {
                              _showImagePreviewDialog(context, url);
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFCBD5E1),
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (url != null && url.isNotEmpty)
                                  CachedNetworkImage(
                                    imageUrl: url,
                                    fit: BoxFit.cover,
                                    placeholder: (_, _) => const Center(
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    ),
                                    errorWidget: (_, _, _) => const Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.picture_as_pdf_rounded,
                                          color: Color(0xFFDC2626),
                                          size: 26,
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          'PDF',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFFDC2626),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.insert_drive_file_outlined,
                                        size: 24,
                                        color: Color(0xFF94A3B8),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'File',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ],
                                  ),

                                // Zoom icon overlay badge
                                if (url != null && url.isNotEmpty)
                                  Positioned(
                                    right: 4,
                                    bottom: 4,
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(
                                          alpha: 0.5,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.zoom_in_rounded,
                                        color: Colors.white,
                                        size: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Clean Footer Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Submission Due Date
                Row(
                  children: [
                    const Icon(
                      Icons.event_outlined,
                      size: 15,
                      color: Color(0xFF475569),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Due: ${item.submissionDate}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ],
                ),

                // Recipients count
                if (item.numberOfStudents > 0)
                  Row(
                    children: [
                      const Icon(
                        Icons.people_alt_outlined,
                        size: 15,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${item.numberOfStudents} ${item.numberOfStudents == 1 ? 'Student' : 'Students'}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassFilterOption {
  _ClassFilterOption({
    required this.classId,
    required this.standard,
    required this.sections,
  });

  final int classId;
  final List<String> sections;
  final String standard;
}
