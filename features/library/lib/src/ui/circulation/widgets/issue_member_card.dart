import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:school_library/school_library.dart';

/// Card showing the selected borrower and their current borrowing standing at the desk.
class IssueMemberCard extends StatelessWidget {
  const IssueMemberCard({
    required this.person,
    this.member,
    this.onChange,
    this.disabled = false,
    super.key,
  });

  final LibraryPerson person;
  final LibraryMember? member;
  final VoidCallback? onChange;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isBlocked = member?.blocked ?? false;
    final activeLoansCount = member?.activeLoans ?? 0;
    final accent = isBlocked ? colorScheme.error : colorScheme.primary;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isBlocked
              ? colorScheme.error
              : colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
            child: Row(
              children: [
                _BorrowerPhoto(person: person, accent: accent),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        person.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          IcueStatusPill(
                            label: person.isStudent ? 'Student' : 'Staff',
                            background: colorScheme.secondaryContainer,
                            color: colorScheme.onSecondaryContainer,
                          ),
                          IcueStatusPill(
                            icon: Icons.badge_outlined,
                            label: 'ID ${person.personErpId}',
                            background: colorScheme.surfaceContainerHighest,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                      if (person.detail.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          person.detail,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (onChange != null)
                  IconButton(
                    tooltip: 'Change borrower',
                    onPressed: disabled ? null : onChange,
                    icon: const Icon(Icons.swap_horiz_rounded),
                    color: colorScheme.primary,
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: isBlocked
                ? colorScheme.errorContainer
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
            child: Row(
              children: [
                Icon(
                  isBlocked ? Icons.block_rounded : Icons.auto_stories_rounded,
                  size: 18,
                  color: isBlocked
                      ? colorScheme.onErrorContainer
                      : activeLoansCount > 0
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    activeLoansCount == 1
                        ? '1 book currently on loan'
                        : '$activeLoansCount books currently on loan',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: activeLoansCount > 0
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: isBlocked
                          ? colorScheme.onErrorContainer
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (isBlocked)
                  Text(
                    'Blocked',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onErrorContainer,
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

/// The ERP photo, or the borrower's initials when there is none or it fails to load.
class _BorrowerPhoto extends StatelessWidget {
  const _BorrowerPhoto({required this.person, required this.accent});

  final LibraryPerson person;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final initials = person.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .take(2)
        .map((word) => word[0].toUpperCase())
        .join();
    final fallback = ColoredBox(
      color: colorScheme.primaryContainer,
      child: Center(
        child: initials.isEmpty
            ? Icon(
                person.isStudent ? Icons.school_rounded : Icons.badge_outlined,
                color: colorScheme.onPrimaryContainer,
              )
            : Text(
                initials,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
      ),
    );

    return Container(
      width: 100,
      height: 100,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: accent, width: 2),
      ),
      child: ClipOval(
        child: person.photoUrl.isEmpty
            ? fallback
            : Image.network(
                person.photoUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
                loadingBuilder: (_, child, progress) =>
                    progress == null ? child : fallback,
              ),
      ),
    );
  }
}
