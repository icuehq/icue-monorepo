import 'package:face_enrollment/src/models/student.dart';
import 'package:face_enrollment/src/providers/student_provider.dart';
import 'package:face_enrollment/src/ui/theme_context.dart';
import 'package:face_enrollment/src/ui/widgets/glass_card.dart';
import 'package:flutter/material.dart';

class StudentFilterBar extends StatefulWidget {
  const StudentFilterBar({
    super.key,
    required this.studentProvider,
    required this.searchController,
  });

  final StudentProvider studentProvider;
  final TextEditingController searchController;

  @override
  State<StudentFilterBar> createState() => _StudentFilterBarState();
}

class _StudentFilterBarState extends State<StudentFilterBar> {
  bool _isSearchExpanded = false;

  @override
  void initState() {
    super.initState();
    if (widget.searchController.text.isNotEmpty) {
      _isSearchExpanded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final studentProvider = widget.studentProvider;
    final int? selectedClassId =
        studentProvider.standards.any(
          (standard) => standard.id == studentProvider.classId,
        )
        ? studentProvider.classId
        : null;

    final int filteredCount = studentProvider.filteredStudents.length;
    final int enrolledCount = studentProvider.enrolledCount;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: GlassCard(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        borderRadius: 18,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Row 1: Class Dropdown and Search Toggle
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: context.scheme.onSurface.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: context.scheme.onSurface.withValues(alpha: 0.1),
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: selectedClassId,
                        isExpanded: true,
                        hint: Row(
                          children: [
                            Icon(
                              Icons.school_outlined,
                              size: 18,
                              color: context.scheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Select Class / Standard',
                              style: TextStyle(
                                fontSize: 13,
                                color: context.scheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                        icon: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: context.scheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                        items: studentProvider.standards.map((
                          Standard standard,
                        ) {
                          return DropdownMenuItem<int>(
                            value: standard.id,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.school_outlined,
                                  size: 16,
                                  color: context.scheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  standard.name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: context.scheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (newClassId) {
                          if (newClassId != null) {
                            studentProvider.setClassId(newClassId);
                          }
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: _isSearchExpanded
                      ? 'Hide Search'
                      : 'Search Students',
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _isSearchExpanded = !_isSearchExpanded;
                        if (!_isSearchExpanded &&
                            widget.searchController.text.isNotEmpty) {
                          widget.searchController.clear();
                          studentProvider.updateSearchQuery('');
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _isSearchExpanded
                            ? context.scheme.primary.withValues(alpha: 0.15)
                            : context.scheme.onSurface.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isSearchExpanded
                              ? context.scheme.primary.withValues(alpha: 0.4)
                              : context.scheme.onSurface.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Icon(
                        _isSearchExpanded
                            ? Icons.search_off_rounded
                            : Icons.search_rounded,
                        size: 20,
                        color: _isSearchExpanded
                            ? context.scheme.primary
                            : context.scheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Animated Search Input Field
            if (_isSearchExpanded) ...[
              const SizedBox(height: 8),
              Container(
                height: 40,
                decoration: BoxDecoration(
                  color: context.scheme.onSurface.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: context.scheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: TextField(
                  controller: widget.searchController,
                  autofocus: true,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.scheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search by student name or ID...',
                    hintStyle: TextStyle(
                      fontSize: 12.5,
                      color: context.scheme.onSurface.withValues(alpha: 0.45),
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      size: 18,
                      color: context.scheme.primary,
                    ),
                    suffixIcon: widget.searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 16),
                            onPressed: () {
                              widget.searchController.clear();
                              studentProvider.updateSearchQuery('');
                              setState(() {});
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                  ),
                  onChanged: (text) {
                    setState(() {});
                    studentProvider.updateSearchQuery(text);
                  },
                ),
              ),
            ],

            const SizedBox(height: 8),

            // Row 2: Photo Filter Chips & Summary Count
            Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip(
                          label: 'All',
                          isSelected:
                              studentProvider.studentPhotoFilter == null,
                          onSelected: () =>
                              studentProvider.togglePhotoFilter(null),
                        ),
                        const SizedBox(width: 6),
                        _buildFilterChip(
                          label: 'With Photo',
                          isSelected:
                              studentProvider.studentPhotoFilter == true,
                          icon: Icons.photo_camera_front_rounded,
                          onSelected: () =>
                              studentProvider.togglePhotoFilter(true),
                        ),
                        const SizedBox(width: 6),
                        _buildFilterChip(
                          label: 'No Photo',
                          isSelected:
                              studentProvider.studentPhotoFilter == false,
                          icon: Icons.no_photography_outlined,
                          onSelected: () =>
                              studentProvider.togglePhotoFilter(false),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Live Summary stats pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: context.scheme.onSurface.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: context.scheme.onSurface.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$filteredCount',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: context.scheme.onSurface,
                        ),
                      ),
                      Text(
                        ' std',
                        style: TextStyle(
                          fontSize: 10,
                          color: context.scheme.onSurface.withValues(
                            alpha: 0.55,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 1,
                        height: 10,
                        color: context.scheme.onSurface.withValues(alpha: 0.15),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.verified_rounded,
                        size: 11,
                        color: Color(0xFF10B981),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '$enrolledCount',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
    IconData? icon,
  }) {
    final Color activeColor = context.scheme.primary;

    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.16)
              : context.scheme.onSurface.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? activeColor.withValues(alpha: 0.6)
                : context.scheme.onSurface.withValues(alpha: 0.08),
            width: isSelected ? 1.2 : 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 12,
                color: isSelected
                    ? activeColor
                    : context.scheme.onSurface.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? activeColor
                    : context.scheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
