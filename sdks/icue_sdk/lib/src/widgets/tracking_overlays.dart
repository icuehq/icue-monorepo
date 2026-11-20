import 'package:bus_tracking_core/bus_tracking_core.dart';
import 'package:flutter/material.dart';
import 'package:icue_sdk/src/dialogs/notifications_dialog.dart';
import 'package:icue_sdk/src/models/live_data.dart';
import 'package:icue_sdk/src/models/user.dart';
import 'package:icue_sdk/src/models/vehicle_location.dart';
import 'package:icue_sdk/src/providers/notifications_provider.dart';
import 'package:icue_sdk/src/providers/user_provider.dart';
import 'package:icue_sdk/src/providers/vehicle_provider.dart';
import 'package:provider/provider.dart';

/// Floating "Connecting to live GPS..." pill shown while the first fix loads.
class ConnectingIndicator extends StatelessWidget {
  const ConnectingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 12,
      left: 0,
      right: 0,
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: Colors.black.withValues(alpha: 0.05),
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.blue,
                  ),
                ),
              ),
              SizedBox(width: 8),
              Text(
                'Connecting to live GPS...',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Animated "GPS signal lost" banner; collapses when [isOffline] is false.
class GpsLostBanner extends StatelessWidget {
  const GpsLostBanner({required this.isOffline, super.key});

  final bool isOffline;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -1),
            end: Offset.zero,
          ).animate(animation),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      child: isOffline
          ? Align(
              key: const ValueKey('gps_lost'),
              alignment: Alignment.topCenter,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50.withValues(
                    alpha: 0.95,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.orange.shade200,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: 0.08,
                      ),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.gps_off_rounded,
                      size: 14,
                      color: Colors.orange.shade700,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'GPS signal lost',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : const SizedBox.shrink(key: ValueKey('gps_ok')),
    );
  }
}

/// App-bar bell that opens the route notifications dialog.
class TrackingNotificationsButton extends StatelessWidget {
  const TrackingNotificationsButton({
    required this.student,
    required this.isTrackingAvailable,
    super.key,
  });

  final User? student;
  final bool isTrackingAvailable;

  @override
  Widget build(BuildContext context) {
    if (!isTrackingAvailable || student?.showNotification != true) {
      return const SizedBox.shrink();
    }

    return Selector<VehicleProvider, (bool?, int?)>(
      selector: (context, prov) =>
          (prov.liveData?.msgAvailable, prov.liveData?.routeTrackId),
      builder: (context, value, _) {
        final msgAvailable = value.$1;
        final routeTrackId = value.$2;
        return Stack(
          alignment: Alignment.topRight,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_none_outlined, size: 40),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => MultiProvider(
                  providers: [
                    ChangeNotifierProvider.value(
                      value: context.read<NotificationsProvider>(),
                    ),
                    ChangeNotifierProvider.value(
                      value: context.read<UserProvider>(),
                    ),
                  ],
                  child: NotificationsDialog(routeTrackId: routeTrackId ?? 0),
                ),
              ),
            ),
            Positioned(
              left: 30,
              top: 10,
              child: CircleAvatar(
                radius: 7,
                backgroundColor:
                    msgAvailable == true ? Colors.green : Colors.red,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Bottom route/ETA/driver card.
class TrackingInfoPanel extends StatelessWidget {
  const TrackingInfoPanel({
    required this.student,
    required this.liveData,
    required this.isTrackingAvailable,
    required this.vehicleLocation,
    super.key,
  });

  final User? student;
  final LiveData? liveData;
  final bool isTrackingAvailable;
  final VehicleLocation? vehicleLocation;

  @override
  Widget build(BuildContext context) {
    final s = student;
    final live = liveData;
    if (!isTrackingAvailable || s == null || s.showRoutePanel != true) {
      return const SizedBox.shrink();
    }
    return TrackingInfoCard(
      bottomSafeArea: false,
      pickPoint: s.pickPoint ?? '-',
      showEta: s.showEta ?? false,
      routeNo: live?.routeNo ?? '-',
      driverMobile: s.showContactNo == true
          ? '${vehicleLocation?.driverData?.mobile ?? ''}'
          : null,
      etaValue: live?.etaValue,
    );
  }
}
