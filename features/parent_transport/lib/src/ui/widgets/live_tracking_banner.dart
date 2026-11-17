import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:parent_l10n/parent_l10n.dart';

/// Header on the home screen announcing live bus tracking.
class LiveTrackingBanner extends StatelessWidget {
  const LiveTrackingBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final l10n = ParentLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        color: const Color.fromRGBO(255, 255, 255, 0.8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            spacing: 16,
            children: [
              SvgPicture.asset(
                'packages/parent_transport/assets/school-bus.svg',
                height: 60,
                colorFilter: ColorFilter.mode(primary, BlendMode.srcIn),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.liveBusTracking,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: primary,
                      ),
                    ),
                    Text(
                      l10n.realTimeTrackingInfo,
                      style: const TextStyle(
                        color: Color(0xFF070707),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
