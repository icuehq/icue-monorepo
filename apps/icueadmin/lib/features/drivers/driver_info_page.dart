import 'package:core_ui/core_ui.dart';
import 'package:drivers/drivers.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/analytics/app_events.dart';
import 'package:icueadmin/features/drivers/widgets/driver_detail_row.dart';
import 'package:icueadmin/features/drivers/widgets/driver_status_chip.dart';
import 'package:icueadmin/routing/app_routes.dart';
import 'package:provider/provider.dart';

class DriverInfoPage extends StatelessWidget {
  const DriverInfoPage({super.key, required this.driver});

  final Driver driver;

  void _confirmDelete(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Driver'),
        content: Text('Are you sure you want to remove ${driver.fullName}?'),
        actions: [
          AppButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(ctx).pop(),
            variant: AppButtonVariant.ghost,
          ),
          AppButton(
            label: 'Delete',
            onPressed: () async {
              Navigator.of(ctx).pop();
              final provider = context.read<DriverProvider>();
              final success = await provider.deleteDriver(driver.id);
              if (context.mounted) {
                if (success) {
                  track(AppEvents.driverDeleted);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Driver deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  context.pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        provider.errorMessage ?? 'Failed to delete driver',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            variant: AppButtonVariant.destructive,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final parsedExpiry = driver.licenceExpiryDate.toDateOrNull();
    final expiryStatus = parsedExpiry?.expiryStatus('License');

    return Scaffold(
      appBar: AppBar(
        title: Text(driver.fullName),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            tooltip: 'Delete Driver',
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 0.5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Theme.of(context).primaryColor
                              .withValues(alpha: 0.15),
                          child: Text(
                            driver.firstName.isNotEmpty
                                ? driver.firstName[0].toUpperCase()
                                : 'D',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                driver.fullName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${driver.mobile ?? 'No phone'}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (expiryStatus != null) ...[
                      const SizedBox(height: 12),
                      DriverStatusChip(label: expiryStatus),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 0.5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Driver Details',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DriverDetailRow(
                      title: 'License Number',
                      value: driver.licenceNumber,
                      isBold: true,
                    ),
                    DriverDetailRow(
                      title: 'License Issued',
                      value: driver.licenceIssuedDate,
                    ),
                    DriverDetailRow(
                      title: 'License Expiry',
                      value: driver.licenceExpiryDate,
                      valueColor: expiryStatus != null ? Colors.red : null,
                    ),
                    DriverDetailRow(
                      title: 'Driving Experience',
                      value: driver.drivingExperience != null
                          ? '${driver.drivingExperience} years'
                          : null,
                    ),
                    DriverDetailRow(
                      title: 'Date of Birth',
                      value: driver.dateOfBirth,
                    ),
                    DriverDetailRow(
                      title: 'Date of Joining',
                      value: driver.dateOfJoining,
                    ),
                    DriverDetailRow(
                      title: 'Alternate Mobile',
                      value: driver.alternateNumber != null
                          ? '${driver.alternateNumber}'
                          : null,
                    ),
                    DriverDetailRow(title: 'Email', value: driver.email),
                    DriverDetailRow(title: 'Aadhar / ID', value: driver.idType),
                    DriverDetailRow(
                      title: 'Address',
                      value:
                          [
                                driver.address.line1,
                                driver.address.line2,
                                driver.city,
                                driver.state,
                                driver.country,
                                driver.pincode != null
                                    ? '${driver.pincode}'
                                    : null,
                              ]
                              .where((s) => s != null && s.trim().isNotEmpty)
                              .join(', '),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Edit Driver',
                    onPressed: () {
                      context.push(AppRoutes.addDriver, extra: driver);
                    },
                    variant: AppButtonVariant.outline,
                    leadingIcon: Icons.edit_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    label: 'Documents',
                    onPressed: () {
                      context.push(AppRoutes.driverDocs, extra: driver);
                    },
                    leadingIcon: Icons.folder_shared_outlined,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
