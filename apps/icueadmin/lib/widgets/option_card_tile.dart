import 'package:flutter/material.dart';
import 'package:icueadmin/widgets/cache_image.dart';

/// A reusable card tile for navigation option items across dashboard and sub-feature screens.
class OptionCardTile extends StatelessWidget {
  const OptionCardTile({
    required this.title,
    this.subtitle,
    this.iconAsset,
    this.networkIconUrl,
    this.leading,
    this.onTap,
    this.margin = const EdgeInsets.only(bottom: 10),
    super.key,
  });

  final String title;
  final String? subtitle;
  final String? iconAsset;
  final String? networkIconUrl;
  final Widget? leading;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry margin;

  static const iconSize = 64.0;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryDark = theme.primaryColorDark;

    Widget? leadingWidget = leading;
    if (leadingWidget == null) {
      if (iconAsset != null && iconAsset!.isNotEmpty) {
        leadingWidget = Image.asset(
          iconAsset!,
          width: iconSize,
          height: iconSize,
          errorBuilder: (_, _, _) =>
              networkIconUrl != null && networkIconUrl!.isNotEmpty
              ? CacheImage(url: networkIconUrl!, size: iconSize)
              : const SizedBox(width: iconSize, height: iconSize),
        );
      } else if (networkIconUrl != null && networkIconUrl!.isNotEmpty) {
        leadingWidget = CacheImage(url: networkIconUrl!, size: iconSize);
      }
    }

    return Card(
      elevation: 1,
      margin: margin,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: onTap,
        leading: leadingWidget != null
            ? SizedBox(
                width: iconSize,
                height: iconSize,
                child: Center(child: leadingWidget),
              )
            : null,
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: theme.primaryColorDark,
          ),
        ),
        subtitle: subtitle != null && subtitle!.isNotEmpty
            ? Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    height: 1.3,
                  ),
                ),
              )
            : null,
        trailing: Icon(
          Icons.arrow_forward_ios_rounded,
          size: 18,
          color: primaryDark,
        ),
      ),
    );
  }
}
