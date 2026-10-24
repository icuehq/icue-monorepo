import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/drivers.dart';
import '../../providers/driver_provider.dart';
import '../../utils/app_utils.dart';

class DriverInfoPage extends StatelessWidget {
  const DriverInfoPage({super.key, required this.driverId});
  final String driverId;

  Widget info(String title, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: Color(0XFF16A087),
              ),
            ),
          ),
          const Text(
            ':  ',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Color(0XFF16A087),
            ),
          ),
          Expanded(
            child: Text(
              value ?? '-',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: Color(0XFF1F1D31),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String maskNumber(String number) {
    if (number.length <= 4) {
      return number;
    }
    return '*' * (number.length - 4) + number.substring(number.length - 4);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DriverProvider>(context);
    final driver = provider.drivers.firstWhere(
      (d) => '${d.id}' == driverId,
      orElse: () => Driver(
        vehicles: [],
        routes: [],
        id: 0,
        firstName: '',
        middleName: '',
        lastName: '',
        mobile: '',
        dateOfBirth: '',
        email: '',
        designation: '',
        licenceNumber: '',
        licenceIssuedDate: '',
        licenceExpiryDate: '',
        licenceCopy: '',
        healthRecord: '',
        policeRecord: '',
        address: Address(line1: '', line2: ''),
        city: '',
        state: '',
        country: '',
        pincode: '',
        identificationId: '',
        enforceChangePassword: false,
        userType: '',
      ),
    );

    final licenceStatus = AppUtils.checkLicenseStatus(
      'License',
      driver.licenceExpiryDate.toDate(),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${driver.firstName} ${driver.middleName ?? ''} ${driver.lastName ?? ''}',
        ),
      ),
      body: Center(
        child: SizedBox(
          width: 600,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              info('Mobile Number', '${driver.mobile ?? '-'}'),
              info('Alternate Number', '${driver.alternateNumber ?? '-'}'),
              info('Licence Number', driver.licenceNumber),
              info(
                'Licence Issued Date',
                driver.licenceIssuedDate.formatAsIndianDate(),
              ),
              if (licenceStatus != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text(
                    licenceStatus,
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              info(
                'Licence Expiry Date',
                driver.licenceExpiryDate.formatAsIndianDate(),
              ),
              info(
                'Address',
                '${driver.address.line1} ${driver.address.line2 ?? ''} ${driver.city ?? ''} ${driver.state ?? ''} ${driver.pincode ?? ''}',
              ),
              info(
                'Date Of Joining',
                driver.dateOfJoining.formatAsIndianDate(),
              ),
              info('Id Type', maskNumber(driver.idType ?? '-')),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        context.go(
                          '/layout.drivers/update-driver',
                          extra: driver,
                        );
                      },
                      child: const Text('Edit'),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        context.go(
                          '/layout.drivers/driver-docs',
                          extra: driver,
                        );
                      },
                      child: const Text('Documents'),
                    ),
                  ),
                  // const SizedBox(width: 20),
                  // Expanded(
                  //   child: OutlinedButton(
                  //     style: OutlinedButton.styleFrom(
                  //       side: const BorderSide(color: Colors.red, width: 2),
                  //     ),
                  //     onPressed: () {
                  //       showDialog(
                  //         context: context,
                  //         builder: (context) => DeleteDialog(
                  //           onDelete: () {
                  //             provider.deleteDriver(context, driver.id);
                  //           },
                  //         ),
                  //       );
                  //     },
                  //     child: const Text(
                  //       'Delete',
                  //       style: TextStyle(color: Colors.red),
                  //     ),
                  //   ),
                  // ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
