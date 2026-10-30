import 'dart:async';

import 'package:flutter/material.dart';
import 'package:icueadmin/features/routes/widgets/change_route_modal.dart';
import 'package:icueadmin/features/routes/widgets/student_route_card.dart';
import 'package:provider/provider.dart';
import 'package:routes/routes.dart';

class StudentRouteChangePage extends StatefulWidget {
  const StudentRouteChangePage({super.key});

  @override
  State<StudentRouteChangePage> createState() => _StudentRouteChangePageState();
}

class _StudentRouteChangePageState extends State<StudentRouteChangePage> {
  int? _selectedClassId;
  String? _selectedSection;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;
  int _pageNo = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<RoutesProvider>().fetchStandards();
      }
    });

    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final provider = context.read<RoutesProvider>();
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !provider.studentsLoading &&
        provider.hasNextPage &&
        _selectedClassId != null &&
        _selectedSection != null) {
      _pageNo++;
      provider.fetchStudents(
        _selectedClassId!,
        [_selectedSection!],
        pageNo: _pageNo,
      );
    }
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final query = _searchController.text.trim();
      final provider = context.read<RoutesProvider>();
      if (query.isNotEmpty) {
        provider.searchStudent(
          query,
          classId: _selectedClassId,
          sections: _selectedSection != null ? [_selectedSection!] : null,
        );
      } else if (_selectedClassId != null && _selectedSection != null) {
        _pageNo = 1;
        provider.fetchStudents(_selectedClassId!, [_selectedSection!]);
      } else {
        provider.clearStudents();
      }
    });
  }

  void _onClassChanged(int? classId) {
    setState(() {
      _selectedClassId = classId;
      _selectedSection = null;
      _pageNo = 1;
    });
    context.read<RoutesProvider>().clearStudents();
  }

  void _onSectionChanged(String? section) {
    setState(() {
      _selectedSection = section;
      _pageNo = 1;
    });
    if (_selectedClassId != null && section != null) {
      context
          .read<RoutesProvider>()
          .fetchStudents(_selectedClassId!, [section]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RoutesProvider>();
    final standards = provider.standards;

    final selectedStandard = _selectedClassId != null
        ? standards.firstWhere(
            (s) => s.id == _selectedClassId,
            orElse: () => standards.first,
          )
        : null;

    final availableSections = selectedStandard?.sections ?? const <Section>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Route Change'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _selectedClassId,
                    hint: const Text('Class', style: TextStyle(fontSize: 13)),
                    isExpanded: true,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    items: standards.map((s) {
                      return DropdownMenuItem(value: s.id, child: Text(s.name));
                    }).toList(),
                    onChanged: _onClassChanged,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedSection,
                    hint: const Text('Section', style: TextStyle(fontSize: 13)),
                    isExpanded: true,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    items: availableSections.map((sec) {
                      return DropdownMenuItem(
                          value: sec.name, child: Text(sec.name));
                    }).toList(),
                    onChanged: _onSectionChanged,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search student by name or roll number...',
                hintStyle:
                    TextStyle(color: Colors.grey.shade400, fontSize: 13),
                prefixIcon:
                    const Icon(Icons.search, size: 20, color: Colors.grey),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged();
                        },
                      )
                    : null,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _buildStudentList(provider),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentList(RoutesProvider provider) {
    if (provider.studentsLoading && provider.students.isEmpty) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    if (_selectedClassId == null || _selectedSection == null) {
      if (_searchController.text.isEmpty) {
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.filter_list_rounded, size: 48, color: Colors.grey),
              SizedBox(height: 8),
              Text(
                'Please select a Class & Section to view students',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
        );
      }
    }

    if (provider.students.isEmpty) {
      return const Center(
        child: Text(
          'No students found.',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: provider.students.length + (provider.hasNextPage ? 1 : 0),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemBuilder: (context, index) {
        if (index == provider.students.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Center(
              child: SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final student = provider.students[index];
        return StudentRouteCard(
          student: student,
          onChangeRoute: () => ChangeRouteModal.show(context, student),
        );
      },
    );
  }
}
