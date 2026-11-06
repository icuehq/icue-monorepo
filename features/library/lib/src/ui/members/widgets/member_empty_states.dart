import 'package:admin_ui/admin_ui.dart';
import 'package:flutter/material.dart';

class MemberInitialEmptyState extends StatelessWidget {
  const MemberInitialEmptyState({required this.memberType, super.key});

  final String memberType;

  @override
  Widget build(BuildContext context) {
    final isStudent = memberType == 'student';
    return EmptyState(
      icon: isStudent ? Icons.school_outlined : Icons.person_outline_rounded,
      title: isStudent
          ? 'No student borrowers yet'
          : 'No teacher borrowers yet',
      message: 'Members are enrolled automatically when they first borrow or reserve a book from the circulation desk.',
    );
  }
}

class MemberNoResultsState extends StatelessWidget {
  const MemberNoResultsState({
    required this.searchQuery,
    required this.onClear,
    super.key,
  });

  final String searchQuery;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => EmptyState.noResults(
    title: 'No members match "$searchQuery"',
    message: 'Try searching by another name, ERP ID, or class number.',
    onAction: onClear,
  );
}
