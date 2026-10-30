import 'package:flutter/material.dart';
import 'package:reports/reports.dart';

class CleaningReportCard extends StatelessWidget {
  const CleaningReportCard({
    required this.report,
    super.key,
  });

  final CleaningReportData report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                  radius: 18,
                  backgroundColor: theme.primaryColor.withValues(alpha: 0.1),
                  child: Icon(
                    Icons.directions_bus_rounded,
                    size: 20,
                    color: theme.primaryColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.vehicleNo.isNotEmpty ? report.vehicleNo : 'Vehicle',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        'By: ${report.createdBy.isNotEmpty ? report.createdBy : "Supervisor"}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${report.createdDate} ${report.createdTime}'.trim(),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            if (report.cleanedData.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: report.cleanedData.map((part) {
                  final isCleaned =
                      part.status.toLowerCase().contains('clean') ||
                      part.status.toLowerCase() == 'yes' ||
                      part.status.toLowerCase() == 'done';
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isCleaned
                          ? Colors.green.shade50
                          : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isCleaned
                            ? Colors.green.shade200
                            : Colors.orange.shade200,
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isCleaned ? Icons.check_circle : Icons.warning_rounded,
                          size: 13,
                          color: isCleaned ? Colors.green.shade700 : Colors.orange.shade800,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          part.name,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isCleaned
                                ? Colors.green.shade900
                                : Colors.orange.shade900,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
            if (report.photos.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 60,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: report.photos.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (ctx, i) {
                    final photoUrl = report.photos[i];
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: GestureDetector(
                        onTap: () {
                          showDialog<void>(
                            context: context,
                            builder: (dCtx) => Dialog(
                              child: Image.network(
                                photoUrl,
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) => const Padding(
                                  padding: EdgeInsets.all(32),
                                  child: Icon(Icons.broken_image, size: 48),
                                ),
                              ),
                            ),
                          );
                        },
                        child: Image.network(
                          photoUrl,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            width: 60,
                            height: 60,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.image, size: 24, color: Colors.grey),
                          ),
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
    );
  }
}
