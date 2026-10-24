import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/vehicle_data.dart';
import '../../providers/vehicle_provider.dart';
import '../../utils/app_utils.dart';

class VehicleDetailsPage extends StatelessWidget {
  const VehicleDetailsPage({super.key, required this.id});

  final String id;

  Widget info(String title, String? value) {
    return Row(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<VehicleProvider>(context);
    VehicleData? vehicle;
    if (provider.vehiclesData.isNotEmpty) {
      vehicle = provider.vehiclesData.firstWhere(
        (vehicle) => '${vehicle.id}' == id,
      );
    }

    final insuranceStatus = AppUtils.checkLicenseStatus(
      'Insurance',
      vehicle?.insuranceExpiryDate.toDate(),
    );
    final rcStatus = AppUtils.checkLicenseStatus(
      'RC',
      vehicle?.rcExpiryDate.toDate(),
    );
    final fitnessStatus = AppUtils.checkLicenseStatus(
      'Fitness',
      vehicle?.fitnessExpiryDate.toDate(),
    );
    final roadTaxStatus = AppUtils.checkLicenseStatus(
      'Road Tax',
      vehicle?.roadTaxExpiryDate.toDate(),
    );
    final pollutionStatus = AppUtils.checkLicenseStatus(
      'Pollution',
      vehicle?.pollutionExpiryDate.toDate(),
    );
    final permitStatus = AppUtils.checkLicenseStatus(
      'Permit',
      vehicle?.permitExpiryDate.toDate(),
    );

    final status = [
      insuranceStatus,
      rcStatus,
      fitnessStatus,
      roadTaxStatus,
      pollutionStatus,
      permitStatus,
    ].whereType<String>().toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Vehicle Details')),
      body: vehicle == null
          ? const SizedBox()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: SizedBox(
                  width: 600,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 10,
                    children: [
                      Row(
                        children: [
                          Text(
                            vehicle.number ?? '',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () {
                              context.go(
                                '/layout.vehicles/vehicle-details/update-vehicle?id=${vehicle!.id}',
                              );
                            },
                            icon: Icon(
                              Icons.edit,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                          // const SizedBox(width: 10),
                          // IconButton(
                          //   onPressed: () {
                          //     showDialog(
                          //       context: context,
                          //       builder: (context) => DeleteDialog(
                          //         onDelete: () {
                          //           provider.deleteVehicle(context, vehicle!.id!);
                          //         },
                          //       ),
                          //     );
                          //   },
                          //   icon: const Icon(Icons.delete, color: Colors.red),
                          // ),
                          const SizedBox(width: 10),
                          IconButton(
                            onPressed: () {
                              context.go(
                                '/layout.vehicles/vehicle-details/vehicle-docs?id=${vehicle!.id}',
                              );
                            },
                            icon: const Icon(Icons.document_scanner),
                          ),
                        ],
                      ),
                      const Divider(),
                      Text(
                        status.join('\n'),
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      info('Make:', vehicle.make),
                      info('Model:', vehicle.model),
                      info('Colour:', vehicle.colour),
                      info('Year:', vehicle.year),
                      info('Fuel Type:', vehicle.fuelType),
                      info('Chassis Number:', vehicle.chasisNumber),
                      info('Engine Number:', vehicle.engineNumber),
                      info('RTA:', vehicle.rtaOfcName),
                      info(
                        'Date of Reg:',
                        vehicle.dateOfReg.formatAsIndianDate(),
                      ),
                      info(
                        'Claimed Mileage:',
                        '${vehicle.companyClaimedMileage}',
                      ),
                      info(
                        'Actual Mileage:',
                        '${vehicle.actualExpectedMileage}',
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Driver Details:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Divider(),
                      info('Driver Name:', vehicle.driverName),
                      info('Driver Number:', '${vehicle.driverNumber}'),
                      const SizedBox(height: 20),
                      const Text(
                        'Insurance Details:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Divider(),
                      info('Insurance Number:', vehicle.insuranceNumber),
                      info(
                        'Insured Date:',
                        vehicle.insuredDate.formatAsIndianDate(),
                      ),
                      const SizedBox(height: 10),
                      info(
                        'Insurance Expiry Date:',
                        vehicle.insuranceExpiryDate.formatAsIndianDate(),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Other Details:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Divider(),
                      info(
                        'RC Expiry Date:',
                        vehicle.rcExpiryDate.formatAsIndianDate(),
                      ),
                      info(
                        'Service Date:',
                        vehicle.serviceDate.formatAsIndianDate(),
                      ),
                      info('Capacity:', '${vehicle.capacity ?? '-'}'),
                      // info('Dash Cam Id:', vehicle.dashcamId),
                      const SizedBox(height: 20),
                      const Text(
                        'Fire Ext:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Divider(),
                      info('Fire Ext Name:', vehicle.fireExtName),
                      info(
                        'Fire Ext Install Date:',
                        vehicle.fireExtInstallDate.formatAsIndianDate(),
                      ),
                      info(
                        'Fire Ext Expiry Date:',
                        vehicle.fireExtExpiryDate.formatAsIndianDate(),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'First Aid Kit:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Divider(),
                      ...List.generate(vehicle.firstAidKit!.length, (index) {
                        final item = vehicle!.firstAidKit?[index];
                        return Column(
                          children: [
                            info('Name:', item?.medicineDetails),
                            info(
                              'Expiry Date:',
                              item?.medicineExpiryDate.formatAsIndianDate(),
                            ),
                            const SizedBox(height: 10),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
