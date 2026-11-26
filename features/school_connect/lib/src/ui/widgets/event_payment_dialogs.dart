import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:parent_l10n/parent_l10n.dart';
import 'package:school_connect/src/models/event_payment.dart';

IcueDialogAction _close(BuildContext context) => IcueDialogAction(
  label: ParentLocalizations.of(context).close,
  onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
);

/// Names of the students a payment covers.
Future<void> showStudentNames(BuildContext context, List<String> names) =>
    IcueDialog.show<void>(
      context,
      title: ParentLocalizations.of(context).students,
      size: IcueDialogSize.small,
      primaryAction: _close(context),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final name in names)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );

/// Extra questions the parent answered when booking.
Future<void> showQuestionAnswers(
  BuildContext context,
  List<QuestionAnswer> items,
) => IcueDialog.show<void>(
  context,
  title: ParentLocalizations.of(context).questionsAndAnswers,
  primaryAction: _close(context),
  content: SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items) ...[
          Text(
            '${item.id}. ${item.question}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(item.answer, style: const TextStyle(fontSize: 15)),
          const Divider(height: 16),
        ],
      ],
    ),
  ),
);
