import 'package:flutter/material.dart';
import 'package:parent_l10n/parent_l10n.dart';
import 'package:students/src/models/student_route_details.dart';

class RouteDetailsCard extends StatelessWidget {
  const RouteDetailsCard({required this.details, super.key});

  final StudentRouteDetails? details;

  @override
  Widget build(BuildContext context) {
    final l10n = ParentLocalizations.of(context);
    final data = details;
    if (data == null || data.routes.isEmpty) {
      return Center(child: Text(l10n.noRouteDetails));
    }
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Text(
          l10n.transportDetails,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        children: [
          for (final route in data.routes)
            _RouteRow(route: route, showTime: data.showPointTime),
        ],
      ),
    );
  }
}

class _RouteRow extends StatelessWidget {
  const _RouteRow({required this.route, required this.showTime});

  final StudentRoute route;
  final bool showTime;

  @override
  Widget build(BuildContext context) {
    final l10n = ParentLocalizations.of(context);
    final primary = Theme.of(context).colorScheme.primary;
    Widget label(String name, String? value) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text.rich(
        TextSpan(
          text: '$name: ',
          style: TextStyle(fontWeight: FontWeight.w600, color: primary),
          children: [
            TextSpan(
              text: value ?? '-',
              style: const TextStyle(color: Colors.black),
            ),
          ],
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          label(l10n.mode, route.mode),
          label(l10n.routeNo, route.routeNumber),
          label(l10n.point, route.pointName),
          if (showTime) label(l10n.time, route.pointTime),
          const Divider(),
        ],
      ),
    );
  }
}
