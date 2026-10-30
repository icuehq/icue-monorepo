import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/features/gatepass/widgets/gatepass_student_card.dart';
import 'package:icueadmin/features/reports/widgets/report_empty_state.dart';
import 'package:icueadmin/routing/app_routes.dart';
import 'package:provider/provider.dart';
import 'package:routes/routes.dart';

class GenerateGatePassPage extends StatefulWidget {
  const GenerateGatePassPage({super.key});

  @override
  State<GenerateGatePassPage> createState() => _GenerateGatePassPageState();
}

class _GenerateGatePassPageState extends State<GenerateGatePassPage> {
  final TextEditingController _searchController = TextEditingController();
  Standards? _selectedStandard;
  String? _selectedSection;
  String _personType = 'STUDENT';
  Timer? _debounce;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RoutesProvider>().fetchStandards();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      if (query.trim().isNotEmpty) {
        context.read<RoutesProvider>().searchStudent(
              query.trim(),
              classId: _selectedStandard?.id,
              sections: _selectedSection != null ? [_selectedSection!] : null,
            );
      } else {
        _fetchStudents(isInitial: true);
      }
    });
  }

  void _fetchStudents({bool isInitial = false}) {
    if (isInitial) _page = 1;
    if (_selectedStandard != null && _selectedSection != null) {
      context.read<RoutesProvider>().fetchStudents(
            _selectedStandard!.id,
            [_selectedSection!],
            pageNo: _page,
          );
    }
  }

  void _loadMore() {
    _page++;
    _fetchStudents();
  }

  @override
  Widget build(BuildContext context) {
    final routesProvider = context.watch<RoutesProvider>();
    final standards = routesProvider.standards;
    final students = routesProvider.students;
    final isLoading = routesProvider.studentsLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Generate Gate Pass'),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).cardColor,
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _personType,
                  decoration: const InputDecoration(
                    labelText: 'For',
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'STUDENT', child: Text('Student')),
                    DropdownMenuItem(value: 'STAFF', child: Text('Staff')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _personType = val);
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<Standards>(
                        initialValue: _selectedStandard,
                        decoration: const InputDecoration(
                          labelText: 'Class / Standard',
                          isDense: true,
                        ),
                        items: standards.map((s) {
                          return DropdownMenuItem(
                            value: s,
                            child: Text(s.name),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedStandard = val;
                            _selectedSection = null;
                          });
                          _searchController.clear();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedSection,
                        decoration: const InputDecoration(
                          labelText: 'Section',
                          isDense: true,
                        ),
                        items: (_selectedStandard?.sections ?? const <Section>[])
                            .map((sec) {
                          return DropdownMenuItem(
                            value: sec.name,
                            child: Text(sec.name),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() => _selectedSection = val);
                          _searchController.clear();
                          _fetchStudents(isInitial: true);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by student name or admission #...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _fetchStudents(isInitial: true);
                            },
                          )
                        : null,
                  ),
                  onChanged: _onSearchChanged,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: isLoading && students.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : students.isEmpty
                    ? ReportEmptyState(
                        icon: Icons.person_search_outlined,
                        message: _selectedStandard == null || _selectedSection == null
                            ? 'Please select standard and section to browse students.'
                            : 'No students found matching your criteria.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: students.length +
                            (routesProvider.hasNextPage ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == students.length) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                child: isLoading
                                    ? const CircularProgressIndicator()
                                    : ElevatedButton(
                                        onPressed: _loadMore,
                                        child: const Text('Load More'),
                                      ),
                              ),
                            );
                          }

                          final student = students[index];
                          return GatePassStudentCard(
                            student: student,
                            onIssue: () {
                              context.push(
                                AppRoutes.confirmGatePass,
                                extra: {
                                  'student': student,
                                  'personType': _personType,
                                },
                              );
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
