import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:timelines_plus/timelines_plus.dart';

import '../../models/complaint_data.dart';
import '../../services/analytics_service.dart';
import '../../services/injectable.dart';
import '../../utils/app_utils.dart';
import '../vehicle_management/reports/image_view.dart';

class ComplaintDetailsPage extends StatefulWidget {
  const ComplaintDetailsPage({super.key, required this.complaint});

  final Complaint complaint;

  @override
  State<ComplaintDetailsPage> createState() => _ComplaintDetailsPageState();
}

class _ComplaintDetailsPageState extends State<ComplaintDetailsPage> {
  @override
  void initState() {
    super.initState();
    getIt<AnalyticsService>().logScreenView(
      screenName: 'complaint-details-page',
      parameters: {'complaintId': widget.complaint.id},
    );
  }

  Widget _buildTimeline(Complaint item) {
    return FixedTimeline.tileBuilder(
      theme: TimelineThemeData(
        nodePosition: 0,
        color: const Color(0xff989898),
        indicatorTheme: const IndicatorThemeData(position: 0, size: 20),
        connectorTheme: const ConnectorThemeData(thickness: 2.5),
      ),
      builder: TimelineTileBuilder.connected(
        connectionDirection: ConnectionDirection.before,
        itemCount: item.details.length,
        contentsBuilder: (_, index) {
          final detail = item.details[index];
          return Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${detail.date.formatAsIndianDate(fallback: '')} ${detail.time.formatAsIndianTime(fallback: '')}',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                _buildDetailContent(detail),
              ],
            ),
          );
        },
        indicatorBuilder: (_, index) {
          return const DotIndicator(
            color: Color(0xff66c97f),
            child: Icon(Icons.check, color: Colors.white, size: 12),
          );
        },
        connectorBuilder: (_, index, _) => SolidLineConnector(
          color: index == 0 ? const Color(0xff66c97f) : null,
        ),
      ),
    );
  }

  Widget _buildDetailContent(Detail detail) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 10,
      children: [
        Text(
          detail.description,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xff9b9b9b),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 5,
          runSpacing: 5,
          children: [
            for (final img in detail.imageUrls)
              IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ImageView(url: img, isBase64: false),
                    ),
                  );
                },
                icon: const Icon(Icons.image, size: 34, color: Colors.grey),
              ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              detail.action,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.deepOrange,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 10),
              decoration: BoxDecoration(
                color: detail.status == 'Open' ? Colors.orange : Colors.green,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                'Status: ${detail.status}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        Text(
          'By: ${detail.createdBy}',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.complaint;

    return Scaffold(
      appBar: AppBar(title: Text(item.vehicleNo)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 20,
          children: [
            Text(
              item.categoryName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            _buildTimeline(item),
            if (item.currStatus != 'Closed')
              ElevatedButton(
                onPressed: () {
                  context.go(
                    '/layout.logbook/layout.complaints/add-complaint',
                    extra: item,
                  );
                },
                child: const Text('Update'),
              ),
          ],
        ),
      ),
    );
  }
}
