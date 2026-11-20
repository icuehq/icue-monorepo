import 'package:icue_ui/icue_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// One dashboard figure; tapping opens [route] when there is one.
class IcueStatTile {
  const IcueStatTile({
    required this.label,
    required this.value,
    this.route,
    this.isAmount = false,
  });

  final String label;
  final num value;
  final String? route;
  final bool isAmount;
}

class IcueStatTileGrid extends StatelessWidget {
  const IcueStatTileGrid({required this.tiles, super.key});

  final List<IcueStatTile> tiles;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 12,
    children: [
      for (final tile in tiles)
        SizedBox(
          width: 160,
          child: Card(
            child: InkWell(
              onTap: tile.route == null
                  ? null
                  : () => context.push(tile.route!),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tile.isAmount
                          ? tile.value.toRupees()
                          : '${tile.value.round()}',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(tile.label),
                  ],
                ),
              ),
            ),
          ),
        ),
    ],
  );
}
