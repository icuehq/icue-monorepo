import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:icueadmin/features/vehicles/widgets/vehicle_doc_upload_dialog.dart';
import 'package:provider/provider.dart';
import 'package:vehicles/vehicles.dart';

class VehicleDocsPage extends StatefulWidget {
  const VehicleDocsPage({super.key, required this.vehicle});

  final VehicleData vehicle;

  @override
  State<VehicleDocsPage> createState() => _VehicleDocsPageState();
}

class _VehicleDocsPageState extends State<VehicleDocsPage> {
  static const List<String> _docTypes = [
    'Insurance',
    'RC',
    'Fitness',
    'RoadTax',
    'Pollution',
    'Permit',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.vehicle.id != null) {
        final provider = context.read<VehicleProvider>();
        for (final doc in _docTypes) {
          provider.fetchVehicleDoc(id: widget.vehicle.id!, type: doc);
        }
      }
    });
  }

  void _onViewDoc(String title, String? url) {
    if (url == null || url.isEmpty) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppBar(
              title: Text('$title Document'),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
            Flexible(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(child: Text('Unable to preview document.')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadDoc(String docType) async {
    final vehicleId = widget.vehicle.id;
    if (vehicleId == null) return;
    final upload = await VehicleDocUploadDialog.show(context, docType);
    if (upload == null || !mounted) return;
    final provider = context.read<VehicleProvider>();
    final file = upload.file;
    final success = await provider.uploadVehicleDoc(
      vehicleId: vehicleId,
      type: docType,
      formData: FormData.fromMap({
        'Source': 'adminapp',
        'Type': docType,
        'RecordId': vehicleId,
        'Target': 'Vehicle',
        'File': MultipartFile.fromBytes(
          file.bytes,
          filename: file.name,
          contentType: file.isPdf
              ? DioMediaType('application', 'pdf')
              : DioMediaType('image', file.name.split('.').last.toLowerCase()),
        ),
        '${docType}Number': upload.number,
        docType == 'Insurance' ? 'InsuredDate' : '${docType}StartDate':
            upload.startDate,
        '${docType}ExpiryDate': upload.expiryDate,
      }),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Document uploaded successfully'
              : (provider.errorMessage ?? 'Failed to upload'),
        ),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  void _confirmDeleteDoc(String docType) {
    if (widget.vehicle.id == null) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete $docType Document'),
        content: Text(
          'Are you sure you want to delete the uploaded $docType document for ${widget.vehicle.number}?',
        ),
        actions: [
          IcueButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(ctx).pop(),
            variant: IcueButtonVariant.ghost,
          ),
          IcueButton(
            label: 'Delete',
            onPressed: () async {
              Navigator.of(ctx).pop();
              final provider = context.read<VehicleProvider>();
              final success = await provider.deleteVehicleDoc(
                vehicleId: widget.vehicle.id!,
                type: docType,
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? '$docType document removed'
                          : (provider.errorMessage ?? 'Failed to delete'),
                    ),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            variant: IcueButtonVariant.destructive,
          ),
        ],
      ),
    );
  }

  DateTime? _resolveExpiryDate(String docType, Docs? doc) {
    String? rawDate;
    switch (docType) {
      case 'Insurance':
        rawDate =
            doc?.insuranceExpiryDate ?? widget.vehicle.insuranceExpiryDate;
      case 'RC':
        rawDate = doc?.rcExpiryDate ?? widget.vehicle.rcExpiryDate;
      case 'Fitness':
        rawDate = doc?.fitnessExpiryDate ?? widget.vehicle.fitnessExpiryDate;
      case 'RoadTax':
        rawDate = doc?.roadTaxExpiryDate ?? widget.vehicle.roadTaxExpiryDate;
      case 'Pollution':
        rawDate =
            doc?.pollutionExpiryDate ?? widget.vehicle.pollutionExpiryDate;
      case 'Permit':
        rawDate = doc?.permitExpiryDate ?? widget.vehicle.permitExpiryDate;
    }
    return rawDate.toDateOrNull();
  }

  String? _resolveDocNumber(String docType, Docs? doc) {
    switch (docType) {
      case 'Insurance':
        return doc?.insuranceNumber ?? widget.vehicle.insuranceNumber;
      case 'RC':
        return doc?.rcNumber ?? widget.vehicle.rcNumber;
      case 'Fitness':
        return doc?.fitnessNumber ?? widget.vehicle.fitnessNumber;
      case 'RoadTax':
        return doc?.roadTaxNumber ?? widget.vehicle.roadTaxNumber;
      case 'Pollution':
        return doc?.pollutionNumber ?? widget.vehicle.pollutionNumber;
      case 'Permit':
        return doc?.permitNumber ?? widget.vehicle.permitNumber;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VehicleProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Vehicle Documents')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Text(
                'Documents for ${widget.vehicle.number}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ..._docTypes.map((docType) {
              final doc = provider.vehicleDocs[docType];
              final expiry = _resolveExpiryDate(docType, doc);
              final docNum = _resolveDocNumber(docType, doc);

              final itemData = IcueDocumentItemData(
                docType: docType,
                title: '$docType Document',
                docNumber: docNum,
                expiryDate: expiry,
                fileUrl: doc?.docUrl,
              );

              return IcueDocumentAccordion(
                document: itemData,
                isLoading: provider.isLoading,
                onViewDocument: doc?.docUrl != null && doc!.docUrl.isNotEmpty
                    ? () => _onViewDoc(docType, doc.docUrl)
                    : null,
                onDeleteDocument: doc?.docUrl != null && doc!.docUrl.isNotEmpty
                    ? () => _confirmDeleteDoc(docType)
                    : null,
                onUploadDocument: () => _uploadDoc(docType),
              );
            }),
          ],
        ),
      ),
    );
  }
}
