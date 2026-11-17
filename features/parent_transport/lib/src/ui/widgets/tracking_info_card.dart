import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:parent_l10n/parent_l10n.dart';
import 'package:url_launcher/url_launcher.dart';

/// Route number, ETA and a call-the-driver button under the live map.
class TrackingInfoCard extends StatelessWidget {
  const TrackingInfoCard({
    required this.pickPoint,
    required this.routeNo,
    required this.showEta,
    this.etaValue,
    this.driverMobile,
    super.key,
  });

  final String pickPoint;
  final String routeNo;
  final bool showEta;
  final String? etaValue;
  final String? driverMobile;

  Future<void> _call(BuildContext context) async {
    final uri = Uri(scheme: 'tel', path: driverMobile);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (context.mounted) {
      IcueToast.error(
        context,
        ParentLocalizations.of(context).cannotLaunchDialer,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ParentLocalizations.of(context);
    return SafeArea(
      top: false,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            spacing: 12,
            children: [
              Text(
                pickPoint,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Divider(),
              Row(
                spacing: 10,
                children: [
                  _InfoItem(
                    icon: Icons.route_outlined,
                    label: l10n.route,
                    value: routeNo,
                  ),
                  if (showEta)
                    _InfoItem(
                      icon: Icons.access_time_outlined,
                      label: l10n.eta,
                      value: etaValue ?? '-',
                      centered: true,
                    ),
                  if (driverMobile != null)
                    InkWell(
                      onTap: () => _call(context),
                      child: Column(
                        spacing: 4,
                        children: [
                          const Icon(Icons.call_outlined, size: 24),
                          Text(
                            l10n.callDriver.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
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
      ),
    );
  }
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
      spacing: 4,
      children: [
        Row(
          mainAxisAlignment: centered
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          spacing: 4,
          children: [
            Icon(icon, size: 24),
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
        Text(
          label.toUpperCase(),
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
      ],
    ),
  );
}
