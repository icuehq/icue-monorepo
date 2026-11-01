import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// One dashboard figure; tapping opens [route] when there is one.
class StatTile {
  const StatTile({
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

class StatTileGrid extends StatelessWidget {
  const StatTileGrid({required this.tiles, super.key});

  final List<StatTile> tiles;

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
                          ? tile.value.toStringAsFixed(2)
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
