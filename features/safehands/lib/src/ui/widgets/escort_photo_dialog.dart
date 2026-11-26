import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';

/// Full-size view of an escort's photo.
Future<void> showEscortPhoto(BuildContext context, String url) =>
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: 400,
          child: InteractiveViewer(
            child: Image.network(
              url,
              errorBuilder: (_, _, _) => Image.asset(IcueAssets.logo),
            ),
          ),
        ),
      ),
    );
