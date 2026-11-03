import 'package:flutter/material.dart';
import 'package:reports/reports.dart';

class AlcoholReportCard extends StatelessWidget {
  const AlcoholReportCard({required this.record, super.key});

  final AlcoholTestRecord record;

  @override
  Widget build(BuildContext context) {
    final isPassed =
        record.alcoholTest.toUpperCase() == 'PASSED' ||
        record.alcoholTestReading == 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: isPassed
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  child: Icon(
                    isPassed
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded,
                    color: isPassed
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.personName.isNotEmpty
                            ? record.personName
                            : 'Driver',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      if (record.personMobile.isNotEmpty)
                        Text(
                          'Mobile: ${record.personMobile}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isPassed
                        ? Colors.green.shade100
                        : Colors.red.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    record.alcoholTest.isNotEmpty
                        ? record.alcoholTest
                        : (isPassed ? 'PASSED' : 'FAILED'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isPassed
                          ? Colors.green.shade800
                          : Colors.red.shade800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reading',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      '${record.alcoholTestReading.toStringAsFixed(2)} mg/L',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Date & Time',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      '${record.submittedDate} ${record.submittedTime}'.trim(),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                if (record.imageUrl.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.image_outlined),
                    tooltip: 'View Photo',
                    onPressed: () {
                      showDialog<void>(
                        context: context,
                        builder: (ctx) => Dialog(
                          child: Image.network(
                            record.imageUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const Padding(
                              padding: EdgeInsets.all(32),
                              child: Icon(Icons.broken_image, size: 48),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
