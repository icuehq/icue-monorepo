import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Pickup point, route number, ETA and a call-the-driver button, shown under
/// the live map. Plain widgets and English text on purpose, so the SDK and the
/// parent app show the same card.
class TrackingInfoCard extends StatelessWidget {
  const TrackingInfoCard({
    required this.pickPoint,
    required this.routeNo,
    required this.showEta,
    this.etaValue,
    this.driverMobile,
    this.bottomSafeArea = true,
    super.key,
  });

  final String pickPoint;
  final String routeNo;
  final bool showEta;
  final String? etaValue;
  final String? driverMobile;

  /// False when an ancestor already pads for the bottom system inset.
  final bool bottomSafeArea;

  Future<void> _call(BuildContext context) async {
    final uri = Uri(scheme: 'tel', path: driverMobile);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot launch phone dialer')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    bottom: bottomSafeArea,
    child: Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              pickPoint,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: [
                _InfoItem(
                  icon: Icons.route_outlined,
                  label: 'Route',
                  value: routeNo,
                ),
                if (showEta)
                  _InfoItem(
                    icon: Icons.access_time_outlined,
                    label: 'ETA',
                    value: etaValue ?? '-',
                    centered: true,
                  ),
                if (driverMobile != null)
                  InkWell(
                    onTap: () => _call(context),
                    child: const Column(
                      children: [
                        Icon(Icons.call_outlined, size: 24),
                        SizedBox(height: 4),
                        Text(
                          'CALL DRIVER',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _InfoItem extends StatelessWidget {
  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
    this.centered = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool centered;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: centered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: centered
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          children: [
            Icon(icon, size: 24),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label.toUpperCase(),
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
      ],
    ),
  );
}
