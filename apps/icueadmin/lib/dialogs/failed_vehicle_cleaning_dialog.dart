import 'package:flutter/material.dart';

import '../models/vehicle_cleaning_success.dart';
import '../utils/app_date_utils.dart';

class FailedVehicleCleaningDialog extends StatelessWidget {
  const FailedVehicleCleaningDialog({super.key, required this.failedData});

  final List<FailedDatum> failedData;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      title: const Text('Failed Vehicle Data'),
      content: SizedBox(
        width: 500,
        child: ListView.separated(
          shrinkWrap: true,
          itemBuilder: (context, index) {
            final data = failedData[index];
            return ListTile(
              title: Text(data.vehicleNo),
              subtitle: Text(
                'Cleaned Date: ${data.cleanedDate.formatAsIndianDate()}\n',
              ),
            );
          },
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemCount: failedData.length,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context, rootNavigator: true).pop();
          },
          child: const Text('Close'),
        ),
      ],
    );
  }
}
