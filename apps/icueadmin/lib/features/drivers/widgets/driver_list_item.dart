import 'package:core_ui/core_ui.dart';
import 'package:drivers/drivers.dart';
import 'package:flutter/material.dart';
import 'package:icueadmin/features/drivers/widgets/driver_status_chip.dart';

class DriverListItem extends StatelessWidget {
  const DriverListItem({
    super.key,
    required this.driver,
    required this.onTap,
  });

  final Driver driver;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final parsedExpiry = AppDateUtils.tryParseDate(driver.licenceExpiryDate);
    final licenceStatus = AppDateUtils.checkExpiryStatus('License', parsedExpiry);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                child: Text(
                  driver.firstName.isNotEmpty
                      ? driver.firstName[0].toUpperCase()
                      : 'D',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driver.fullName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${driver.mobile ?? 'No phone'}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    if (licenceStatus != null) ...[
                      const SizedBox(height: 6),
                      DriverStatusChip(label: licenceStatus),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
